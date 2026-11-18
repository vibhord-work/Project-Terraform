resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-${var.environment}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn


  container_definitions = jsonencode([
    {

      name      = "frontend"
      image     = "${aws_ecr_repository.frontend.repository_url}:build-8-c1a4bc972ec5df1e572d6fc2bb5ed6e0061bb427"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      memoryReservation = 256

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_frontend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])



  tags = {
    Name        = "${var.project_name}-${var.environment}-frontend-task"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-${var.environment}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  cpu    = "512"
  memory = "1024"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "${aws_ecr_repository.backend.repository_url}:build-8-c1a4bc972ec5df1e572d6fc2bb5ed6e0061bb427"
      essential = true

      portMappings = [
        {
          containerPort = 8081
          protocol      = "tcp"
        }
      ]

      memoryReservation = 512

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_backend.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "backend"
        }
      }

      environment = [
        {
          name  = "DB_HOST"
          value = var.use_ecs_mysql ? "mysql.db.internal" : aws_db_instance.project_mysql.address
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_NAME"
          value = var.use_ecs_mysql ? var.mysql_database_name : aws_db_instance.project_mysql.db_name
        }
      ]

      secrets = [
        {
          name      = "DB_USER"
          valueFrom = var.use_ecs_mysql ? "${aws_secretsmanager_secret.ecs_mysql_credentials.arn}:username::" : "${aws_db_instance.project_mysql.master_user_secret[0].secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = var.use_ecs_mysql ? "${aws_secretsmanager_secret.ecs_mysql_credentials.arn}:password::" : "${aws_db_instance.project_mysql.master_user_secret[0].secret_arn}:password::"
        },

        {
          name      = "MANAGER_PASSWORD_HASH"
          valueFrom = data.aws_secretsmanager_secret.manager_password_hash.arn
        },
        {
          name      = "MANAGER_SESSION_SECRET"
          valueFrom = data.aws_secretsmanager_secret.manager_session_secret.arn
        },
      ]
    }
  ])

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-task"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
