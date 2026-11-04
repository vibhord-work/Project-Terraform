resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  description = "Security group for public ALB"
  vpc_id      = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "Public HTTP access"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb_sg.id
  referenced_security_group_id = aws_security_group.ecs_task_sg.id
  description                  = "HTTP to frontend ECS tasks"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "ecs_sg" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-host-"
  description = "Security group for ECS EC2 hosts"
  vpc_id      = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-host-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_host_outbound" {
  security_group_id = aws_security_group.ecs_sg.id
  description       = "ECS agent and image pull connectivity"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "ecs_task_sg" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-task-"
  description = "Security group for ECS application tasks"
  vpc_id      = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-task-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.ecs_task_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  description                  = "Frontend HTTP traffic from ALB"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ecs_task_outbound" {
  security_group_id = aws_security_group.ecs_task_sg.id
  description       = "Outbound application connectivity"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "mysql_sg" {
  name_prefix = "${var.project_name}-${var.environment}-mysql-"
  description = "Reserved for separately hosted MySQL"
  vpc_id      = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-mysql-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_tasks" {
  security_group_id            = aws_security_group.mysql_sg.id
  referenced_security_group_id = aws_security_group.ecs_task_sg.id
  description                  = "MySQL from ECS application tasks"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "backend_from_alb" {
  security_group_id            = aws_security_group.ecs_task_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  description                  = "Allow backend API traffic from ALB"
  from_port                    = 8081
  to_port                      = 8081
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_backend" {
  security_group_id            = aws_security_group.alb_sg.id
  referenced_security_group_id = aws_security_group.ecs_task_sg.id
  description                  = "Allow ALB traffic to backend ECS tasks"
  from_port                    = 8081
  to_port                      = 8081
  ip_protocol                  = "tcp"
}
