data "archive_file" "github_webhook_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/github_webhook"
  output_path = "${path.module}/github_webhook_lambda.zip"
}

resource "aws_lambda_function" "github_webhook" {
  function_name    = "${var.project_name}-${var.environment}-github-webhook"
  role             = aws_iam_role.github_webhook_lambda.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.github_webhook_lambda.output_path
  source_code_hash = data.archive_file.github_webhook_lambda.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      GITHUB_SECRET_NAME  = data.aws_secretsmanager_secret.github_webhook_secret.name
      JENKINS_INSTANCE_ID = aws_instance.jenkins.id
      SSM_DOCUMENT_NAME   = aws_ssm_document.jenkins_webhook_trigger.name
      DELIVERY_TABLE_NAME = aws_dynamodb_table.github_webhook_deliveries.name
    }
  }

  depends_on = [
    aws_iam_role_policy.github_webhook_lambda,
    aws_iam_role_policy.github_webhook_dynamodb,
    aws_cloudwatch_log_group.github_webhook_lambda
  ]
}

resource "aws_apigatewayv2_api" "github_webhook" {
  name          = "${var.project_name}-${var.environment}-github-webhook"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "github_webhook" {
  api_id                 = aws_apigatewayv2_api.github_webhook.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.github_webhook.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "github_webhook" {
  api_id    = aws_apigatewayv2_api.github_webhook.id
  route_key = "POST /github-webhook"
  target    = "integrations/${aws_apigatewayv2_integration.github_webhook.id}"
}

resource "aws_apigatewayv2_stage" "github_webhook" {
  api_id      = aws_apigatewayv2_api.github_webhook.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 5
    throttling_rate_limit  = 2
  }
}

resource "aws_lambda_permission" "github_webhook_apigateway" {
  statement_id  = "AllowGitHubWebhookAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_webhook.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.github_webhook.execution_arn}/*/POST/github-webhook"
}

output "github_webhook_url" {
  description = "GitHub webhook HTTPS endpoint"
  value       = "${aws_apigatewayv2_api.github_webhook.api_endpoint}/github-webhook"
}
