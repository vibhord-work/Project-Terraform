resource "aws_ecs_capacity_provider" "ecs" {
  name = "${var.project_name}-${var.environment}-ecs-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
      instance_warmup_period    = 300
    }

    managed_termination_protection = "ENABLED"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-capacity-provider"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecs_cluster_capacity_providers" "project_cluster" {
  cluster_name = aws_ecs_cluster.project_cluster.name

  capacity_providers = [
    aws_ecs_capacity_provider.ecs.name
  ]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs.name
    weight            = 1
    base              = 0
  }
}
