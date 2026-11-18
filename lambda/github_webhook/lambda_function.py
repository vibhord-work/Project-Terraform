
import base64
import hashlib
import hmac
import json
import os
import time

import boto3
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Attr

secrets = boto3.client("secretsmanager")
ssm = boto3.client("ssm")
table = boto3.resource("dynamodb").Table(
    os.environ["DELIVERY_TABLE_NAME"]
)


def response(status, message):
    return {
        "statusCode": status,
        "body": json.dumps({"message": message})
    }


def lambda_handler(event, context):

    headers = {
        k.lower(): v
        for k, v in (event.get("headers") or {}).items()
    }

    body = event.get("body") or ""

    raw_body = (
        base64.b64decode(body)
        if event.get("isBase64Encoded")
        else body.encode("utf-8")
    )

    # Verify GitHub webhook signature
    secret = secrets.get_secret_value(
        SecretId=os.environ["GITHUB_SECRET_NAME"]
    )["SecretString"]

    expected = "sha256=" + hmac.new(
        secret.encode(),
        raw_body,
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(
        headers.get("x-hub-signature-256", ""),
        expected
    ):
        return response(401, "Invalid signature")

    # Accept only push events
    if headers.get("x-github-event") != "push":
        return response(200, "Event ignored")

    payload = json.loads(raw_body)

    # Validate repository and branch
    if payload.get("repository", {}).get("full_name") != \
            "vibhord-work/Project-Application":
        return response(403, "Repository not allowed")

    if payload.get("ref") != "refs/heads/main" or payload.get("deleted"):
        return response(200, "Branch ignored")

    # Prevent duplicate webhook deliveries
    delivery_id = headers.get("x-github-delivery")

    if not delivery_id:
        return response(400, "Missing delivery ID")

    try:
        table.put_item(
            Item={
                "delivery_id": delivery_id,
                "expires_at": int(time.time()) + 86400
            },
            ConditionExpression=Attr("delivery_id").not_exists()
        )

    except ClientError as error:
        if error.response["Error"]["Code"] == \
                "ConditionalCheckFailedException":
            return response(200, "Duplicate delivery ignored")
        raise

    # Trigger Jenkins through AWS SSM
    try:
        result = ssm.send_command(
            InstanceIds=[os.environ["JENKINS_INSTANCE_ID"]],
            DocumentName=os.environ["SSM_DOCUMENT_NAME"],
            Comment="GitHub push: trigger pipeline-ci"
        )

        print("SSM Command ID:", result["Command"]["CommandId"])

    except Exception:
        table.delete_item(
            Key={"delivery_id": delivery_id}
        )
        raise

    return response(202, "pipeline-ci trigger submitted")
