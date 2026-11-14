data "aws_secretsmanager_secret" "jenkins_webhook_credentials" {
  name = "project/poc/jenkins-webhook-credentials"
}

data "aws_secretsmanager_secret" "github_webhook_secret" {
  name = "project/poc/github-webhook-secret"
}

data "aws_iam_policy_document" "jenkins_webhook_secret_access" {
  statement {
    sid     = "ReadJenkinsWebhookCredentials"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      data.aws_secretsmanager_secret.jenkins_webhook_credentials.arn
    ]
  }
}

resource "aws_iam_role_policy" "jenkins_webhook_secret_access" {
  name   = "${var.project_name}-${var.environment}-jenkins-webhook-secret-access"
  role   = aws_iam_role.jenkins_role.id
  policy = data.aws_iam_policy_document.jenkins_webhook_secret_access.json
}
