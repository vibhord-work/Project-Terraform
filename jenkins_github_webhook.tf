resource "aws_lb_listener_rule" "jenkins_github_webhook" {
  listener_arn = aws_lb_listener.jenkins_https.arn
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }

  condition {
    host_header {
      values = ["jenkins.vibhordew.space"]
    }
  }

  condition {
    path_pattern {
      values = ["/github-webhook/"]
    }
  }
}
