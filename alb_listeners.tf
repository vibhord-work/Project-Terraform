# -----------------------------------------
# HTTP Listener
# -----------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.project_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-http-listener"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# -----------------------------------------
# Backend API Routing Rule
# -----------------------------------------

resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api", "/api/*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-backend-api-rule"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
