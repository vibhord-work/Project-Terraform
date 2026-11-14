data "aws_iam_policy_document" "jenkins_deployment" {

  statement {
    sid       = "ECRAuthorization"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECRImagePush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:460249938865:repository/project-poc-frontend",
      "arn:aws:ecr:${var.aws_region}:460249938865:repository/project-poc-backend"
    ]
  }

  statement {
    sid = "ECSDescribeTaskDefinitions"
    actions = [
      "ecs:DescribeTaskDefinition"
    ]
    resources = [
      "arn:aws:ecs:${var.aws_region}:460249938865:task-definition/project-poc-frontend:*",
      "arn:aws:ecs:${var.aws_region}:460249938865:task-definition/project-poc-backend:*"
    ]
  }

  statement {
    sid = "ECSRegisterTaskDefinitions"
    actions = [
      "ecs:RegisterTaskDefinition"
    ]
    resources = [
      "arn:aws:ecs:${var.aws_region}:460249938865:task-definition/project-poc-frontend:*",
      "arn:aws:ecs:${var.aws_region}:460249938865:task-definition/project-poc-backend:*"
    ]
  }

  statement {
    sid = "ECSServiceDeployment"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices"
    ]
    resources = [
      "arn:aws:ecs:${var.aws_region}:460249938865:service/project-poc-ecs-cluster/project-poc-frontend-service",
      "arn:aws:ecs:${var.aws_region}:460249938865:service/project-poc-ecs-cluster/project-poc-backend-service"
    ]
  }

  statement {
    sid     = "PassECSTaskRoles"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution_role.arn,
      aws_iam_role.ecs_task_role.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "jenkins_deployment" {
  name   = "${var.project_name}-${var.environment}-jenkins-deployment"
  role   = aws_iam_role.jenkins_role.id
  policy = data.aws_iam_policy_document.jenkins_deployment.json
}
