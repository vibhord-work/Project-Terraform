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
      image     = "${aws_ecr_repository.frontend.repository_url}:v1"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol     = "tcp"
        }
      ]
      memoryReservation = 256
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
      image     = "${aws_ecr_repository.backend.repository_url}:v1"
      essential = true

      portMappings = [
        {
          containerPort = 8081
          protocol      = "tcp"
        }
      ]

      memoryReservation = 512

      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.project_mysql.address
        },
        {
          name  = "DB_PORT"
          value = "3306"
        },
        {
          name  = "DB_NAME"
          value = aws_db_instance.project_mysql.db_name
        }
      ]

      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${aws_db_instance.project_mysql.master_user_secret[0].secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.project_mysql.master_user_secret[0].secret_arn}:password::"
        }
      ]
    }
  ])

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-task"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
