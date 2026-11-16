# --------------------------------------------------
# POC HTTPS certificate
# --------------------------------------------------

data "aws_acm_certificate" "poc" {
  domain      = "poc.vibhordew.space"
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_lb_listener_certificate" "poc" {
  listener_arn    = aws_lb_listener.jenkins_https.arn
  certificate_arn = data.aws_acm_certificate.poc.arn
}

# --------------------------------------------------
# HTTP -> HTTPS redirect for POC
# --------------------------------------------------

resource "aws_lb_listener_rule" "poc_http_redirect" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      host        = "#{host}"
      path        = "/#{path}"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = ["poc.vibhordew.space"]
    }
  }
}

# --------------------------------------------------
# HTTPS backend API routing
# --------------------------------------------------

resource "aws_lb_listener_rule" "poc_https_backend" {
  listener_arn = aws_lb_listener.jenkins_https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    host_header {
      values = ["poc.vibhordew.space"]
    }
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# --------------------------------------------------
# HTTPS frontend routing
# --------------------------------------------------

resource "aws_lb_listener_rule" "poc_https_frontend" {
  listener_arn = aws_lb_listener.jenkins_https.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    host_header {
      values = ["poc.vibhordew.space"]
    }
  }
}
