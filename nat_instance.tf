data "aws_ssm_parameter" "nat_instance_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "nat_instance_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nat_instance" {
  count = var.enable_nat_instance ? 1 : 0

  name               = "${var.project_name}-${var.environment}-nat-instance-role"
  assume_role_policy = data.aws_iam_policy_document.nat_instance_assume_role.json
}

resource "aws_iam_role_policy_attachment" "nat_instance_ssm" {
  count = var.enable_nat_instance ? 1 : 0

  role       = aws_iam_role.nat_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat_instance" {
  count = var.enable_nat_instance ? 1 : 0

  name = "${var.project_name}-${var.environment}-nat-instance-profile"
  role = aws_iam_role.nat_instance[0].name
}

resource "aws_security_group" "nat_instance" {
  count = var.enable_nat_instance ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-nat-instance-"
  description = "NAT instance: accept forwarded traffic only from this VPC"
  vpc_id      = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-instance-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_private_subnets" {
  count = var.enable_nat_instance ? length(var.private_subnet_cidrs) : 0

  security_group_id = aws_security_group.nat_instance[0].id
  description       = "Forwarded traffic from private subnet ${var.private_subnet_cidrs[count.index]}"
  cidr_ipv4         = var.private_subnet_cidrs[count.index]
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "nat_outbound" {
  count = var.enable_nat_instance ? 1 : 0

  security_group_id = aws_security_group.nat_instance[0].id
  description       = "Outbound internet access for private subnet workloads"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "nat_instance" {
  count = var.enable_nat_instance ? 1 : 0

  ami                         = data.aws_ssm_parameter.nat_instance_ami.value
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.nat_instance[0].id]
  associate_public_ip_address = false
  source_dest_check           = false
  iam_instance_profile        = aws_iam_instance_profile.nat_instance[0].name

  user_data_replace_on_change = true
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf install -y iptables-services

    PRIMARY_INTERFACE=$(ip -o -4 route show to default | awk '{print $5; exit}')
    test -n "$PRIMARY_INTERFACE"

    sysctl -w net.ipv4.ip_forward=1
    printf 'net.ipv4.ip_forward = 1\n' > /etc/sysctl.d/99-nat-instance.conf

    iptables -t nat -C POSTROUTING -o "$PRIMARY_INTERFACE" -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -o "$PRIMARY_INTERFACE" -j MASQUERADE

    iptables -C FORWARD -i "$PRIMARY_INTERFACE" -o "$PRIMARY_INTERFACE" \
      -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
      iptables -A FORWARD -i "$PRIMARY_INTERFACE" -o "$PRIMARY_INTERFACE" \
      -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

    iptables -C FORWARD -i "$PRIMARY_INTERFACE" -o "$PRIMARY_INTERFACE" -j ACCEPT 2>/dev/null || \
      iptables -A FORWARD -i "$PRIMARY_INTERFACE" -o "$PRIMARY_INTERFACE" -j ACCEPT

    iptables-save > /etc/sysconfig/iptables
    systemctl enable --now iptables
  EOF

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-instance"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Role        = "nat"
  }

  depends_on = [aws_iam_role_policy_attachment.nat_instance_ssm]
}

resource "aws_eip" "nat_instance" {
  count = var.enable_nat_instance ? 1 : 0

  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-instance-eip"
  }
}

resource "aws_eip_association" "nat_instance" {
  count = var.enable_nat_instance ? 1 : 0

  allocation_id = aws_eip.nat_instance[0].id
  instance_id   = aws_instance.nat_instance[0].id
}
