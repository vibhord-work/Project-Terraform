resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-${var.environment}-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.project_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-frontend-tg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-${var.environment}-backend-tg"
  port        = 8081
  protocol    = "HTTP"
  vpc_id      = aws_vpc.project_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/doctors"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-tg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
