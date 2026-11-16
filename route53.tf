data "aws_route53_zone" "root" {
  zone_id      = "Z01297601WP45KDNIBRS5"
  private_zone = false
}

# Application domain -> ALB
resource "aws_route53_record" "poc" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "poc.vibhordew.space"
  type    = "A"

  alias {
    name                   = aws_lb.project_alb.dns_name
    zone_id                = aws_lb.project_alb.zone_id
    evaluate_target_health = false
  }
}

# Jenkins domain -> ALB
resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "jenkins.vibhordew.space"
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.project_alb.dns_name]
}
