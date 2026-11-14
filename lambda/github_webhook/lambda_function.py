import base64
import hashlib
import hmac
import json
import os
import time
import uuid

import boto3
from botocore.exceptions import ClientError

secretsmanager = boto3.client("secretsmanager")
ssm = boto3.client("ssm")
dynamodb = boto3.client("dynamodb")


def response(status, message):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"message": message})
    }


def lambda_handler(event, context):
    headers = {
        k.lower(): v
        for k, v in (event.get("headers") or {}).items()
    }

    body = event.get("body") or ""

    try:
        raw_body = (
            base64.b64decode(body, validate=True)
            if event.get("isBase64Encoded")
            else body.encode("utf-8")
        )
    except (ValueError, TypeError):
        return response(400, "Invalid request body")

    signature = headers.get("x-hub-signature-256", "")

    if not signature.startswith("sha256="):
        return response(401, "Missing signature")

    webhook_secret = secretsmanager.get_secret_value(
        SecretId=os.environ["GITHUB_SECRET_NAME"]
    )["SecretString"]

    expected = "sha256=" + hmac.new(
        webhook_secret.encode("utf-8"),
        raw_body,
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(signature, expected):
        return response(401, "Invalid signature")

    if headers.get("x-github-event") != "push":
        return response(200, "Event ignored")

    try:
        payload = json.loads(raw_body)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return response(400, "Invalid JSON")

    if payload.get("repository", {}).get("full_name") != \
            "vibhord-work/Project-Application":
        return response(403, "Repository not allowed")

    if payload.get("ref") != "refs/heads/main" or payload.get("deleted"):
        return response(200, "Branch ignored")

    delivery_id = headers.get("x-github-delivery", "")

    try:
        uuid.UUID(delivery_id)
    except (ValueError, AttributeError):
        return response(400, "Invalid delivery ID")

    table = os.environ["DELIVERY_TABLE_NAME"]

    try:
        dynamodb.put_item(
            TableName=table,
            Item={
                "delivery_id": {"S": delivery_id},
                "expires_at": {"N": str(int(time.time()) + 86400)}
            },
            ConditionExpression="attribute_not_exists(delivery_id)"
        )
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return response(200, "Duplicate delivery ignored")
        raise

    try:
        result = ssm.send_command(
            InstanceIds=[os.environ["JENKINS_INSTANCE_ID"]],
            DocumentName=os.environ["SSM_DOCUMENT_NAME"],
            Comment="GitHub webhook: trigger Jenkins pipeline"
        )
    except Exception:
        # Allow GitHub to retry when command submission fails.
        dynamodb.delete_item(
            TableName=table,
            Key={"delivery_id": {"S": delivery_id}}
        )
        raise

    print("SSM command submitted:", result["Command"]["CommandId"])

    return response(202, "Jenkins trigger submitted")
