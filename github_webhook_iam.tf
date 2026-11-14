data "aws_iam_policy_document" "github_webhook_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_webhook_lambda" {
  name               = "${var.project_name}-${var.environment}-github-webhook-lambda"
  assume_role_policy = data.aws_iam_policy_document.github_webhook_assume_role.json
}

data "aws_iam_policy_document" "github_webhook_lambda" {
  statement {
    sid       = "ReadGitHubWebhookSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [data.aws_secretsmanager_secret.github_webhook_secret.arn]
  }

  statement {
    sid     = "TriggerJenkinsViaSSM"
    actions = ["ssm:SendCommand"]
    resources = [
      aws_ssm_document.jenkins_webhook_trigger.arn,
      aws_instance.jenkins.arn
    ]
  }

  statement {
    sid       = "WriteCloudWatchLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.github_webhook_lambda.arn}:*"]
  }
}

resource "aws_iam_role_policy" "github_webhook_lambda" {
  name   = "${var.project_name}-${var.environment}-github-webhook-policy"
  role   = aws_iam_role.github_webhook_lambda.id
  policy = data.aws_iam_policy_document.github_webhook_lambda.json
}

resource "aws_cloudwatch_log_group" "github_webhook_lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-github-webhook"
  retention_in_days = 14
}

resource "aws_iam_role_policy" "github_webhook_dynamodb" {
  name = "${var.project_name}-${var.environment}-github-webhook-dynamodb"
  role = aws_iam_role.github_webhook_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = aws_dynamodb_table.github_webhook_deliveries.arn
      }
    ]
  })
}
