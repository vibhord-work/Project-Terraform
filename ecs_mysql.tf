# Dedicated ECS EC2 capacity and persistent MySQL storage.
# The RDS instance remains provisioned and is the backend default until
# var.use_ecs_mysql is explicitly enabled after data migration verification.

resource "random_password" "mysql_root" {
  length           = 32
  special          = false
  override_special = ""
}

resource "random_password" "mysql_app" {
  length           = 32
  special          = false
  override_special = ""
}

resource "aws_secretsmanager_secret" "ecs_mysql_credentials" {
  name                    = "${var.project_name}/${var.environment}/ecs-mysql-credentials"
  description             = "Credentials for the ECS-hosted HospitalDBMS MySQL service"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-mysql-credentials"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "ecs_mysql_credentials" {
  secret_id = aws_secretsmanager_secret.ecs_mysql_credentials.id
  secret_string = jsonencode({
    root_password = random_password.mysql_root.result
    username      = "admin"
    password      = random_password.mysql_app.result
  })
}

resource "aws_cloudwatch_log_group" "ecs_mysql" {
  name              = "/ecs/${var.project_name}-${var.environment}-mysql"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ebs_volume" "mysql_data" {
  availability_zone = aws_subnet.private[0].availability_zone
  size              = var.mysql_data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-mysql-data"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Role        = "mysql-data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_instance" "mysql_ecs_host" {
  ami                         = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type               = var.mysql_host_instance_type
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.ecs_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ecs_instance_profile.name
  associate_public_ip_address = false

  user_data_replace_on_change = true
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    systemctl stop ecs || true
    dnf install -y xfsprogs

    DATA_DEVICE="/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${replace(aws_ebs_volume.mysql_data.id, "-", "")}"
    for attempt in $(seq 1 120); do
      if [ -b "$DATA_DEVICE" ]; then
        break
      fi
      sleep 5
    done
    test -b "$DATA_DEVICE"

    if ! blkid "$DATA_DEVICE"; then
      mkfs -t xfs "$DATA_DEVICE"
    fi

    DATA_UUID=$(blkid -s UUID -o value "$DATA_DEVICE")
    mkdir -p /mnt/mysql-data
    grep -q "$DATA_UUID" /etc/fstab || echo "UUID=$DATA_UUID /mnt/mysql-data xfs defaults,nofail 0 2" >> /etc/fstab
    mount /mnt/mysql-data
    chmod 750 /mnt/mysql-data

    cat > /etc/ecs/ecs.config <<'ECS_CONFIG'
    ECS_CLUSTER=${aws_ecs_cluster.project_cluster.name}
    ECS_INSTANCE_ATTRIBUTES={"role":"database"}
    ECS_ENABLE_TASK_IAM_ROLE=true
    ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
    ECS_CONFIG

    systemctl enable ecs
    systemctl start ecs
  EOF

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-mysql-ecs-host"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Role        = "database"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_instance_policy,
    aws_iam_role_policy_attachment.ecs_instance_ssm
  ]
}

resource "aws_volume_attachment" "mysql_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.mysql_data.id
  instance_id = aws_instance.mysql_ecs_host.id

  stop_instance_before_detaching = true
}

resource "aws_service_discovery_private_dns_namespace" "database" {
  name        = "db.internal"
  description = "Private service discovery namespace for project databases"
  vpc         = aws_vpc.project_vpc.id
}

resource "aws_service_discovery_service" "mysql" {
  name = "mysql"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.database.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "mysql" {
  family                   = "${var.project_name}-${var.environment}-mysql"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  cpu    = "512"
  memory = "1024"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "mysql"
      image     = "mysql:8.0"
      essential = true

      portMappings = [
        {
          containerPort = 3306
          hostPort      = 3306
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "MYSQL_DATABASE"
          value = var.mysql_database_name
        },
        {
          name  = "MYSQL_USER"
          value = "admin"
        }
      ]

      secrets = [
        {
          name      = "MYSQL_ROOT_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.ecs_mysql_credentials.arn}:root_password::"
        },
        {
          name      = "MYSQL_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.ecs_mysql_credentials.arn}:password::"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "mysql-data"
          containerPath = "/var/lib/mysql"
          readOnly      = false
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -uroot -p\$MYSQL_ROOT_PASSWORD || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 90
      }

      memoryReservation = 768

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_mysql.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mysql"
        }
      }
    }
  ])

  volume {
    name      = "mysql-data"
    host_path = "/mnt/mysql-data"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-mysql-task"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecs_service" "mysql" {
  name            = "${var.project_name}-${var.environment}-mysql-service"
  cluster         = aws_ecs_cluster.project_cluster.id
  task_definition = aws_ecs_task_definition.mysql.arn
  desired_count   = 1
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:role == database"
  }

  network_configuration {
    subnets          = [aws_subnet.private[0].id]
    security_groups  = [aws_security_group.mysql_sg.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.mysql.arn
    port         = 3306
  }

  depends_on = [
    aws_volume_attachment.mysql_data,
    aws_cloudwatch_log_group.ecs_mysql,
    aws_iam_role_policy.ecs_mysql_secret_access
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-mysql-service"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "ecs_mysql_secret_access" {
  statement {
    sid       = "ReadECSMySQLCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.ecs_mysql_credentials.arn]
  }
}

resource "aws_iam_role_policy" "ecs_mysql_secret_access" {
  name   = "${var.project_name}-${var.environment}-ecs-mysql-secret-access"
  role   = aws_iam_role.ecs_task_execution_role.id
  policy = data.aws_iam_policy_document.ecs_mysql_secret_access.json
}
