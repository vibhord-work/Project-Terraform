resource "aws_ecs_cluster" "project_cluster" {
  name = "${var.project_name}-${var.environment}-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-cluster"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}