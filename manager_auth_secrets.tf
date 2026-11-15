
data "aws_secretsmanager_secret" "manager_password_hash" {
  name = "project/poc/manager-password-hash"
}

data "aws_secretsmanager_secret" "manager_session_secret" {
  name = "project/poc/manager-session-secret"
}

data "aws_iam_policy_document" "manager_auth_secret_access" {
  statement {
    sid     = "ReadManagerAuthSecrets"
    actions = ["secretsmanager:GetSecretValue"]

    resources = [
      data.aws_secretsmanager_secret.manager_password_hash.arn,
      data.aws_secretsmanager_secret.manager_session_secret.arn
    ]
  }
}

resource "aws_iam_role_policy" "manager_auth_secret_access" {
  name   = "${var.project_name}-${var.environment}-manager-auth-secrets"
  role   = aws_iam_role.ecs_task_execution_role.id
  policy = data.aws_iam_policy_document.manager_auth_secret_access.json
}
