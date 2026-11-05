resource "aws_autoscaling_group" "ecs" {
  name = "${var.project_name}-${var.environment}-ecs-asg"

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  vpc_zone_identifier = aws_subnet.private[*].id

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  protect_from_scale_in = true

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}