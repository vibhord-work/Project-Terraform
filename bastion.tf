
data "aws_ssm_parameter" "bastion_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion_role" {
  name               = "${var.project_name}-${var.environment}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.project_name}-${var.environment}-bastion-profile"
  role = aws_iam_role.bastion_role.name
}

resource "aws_security_group" "bastion_sg" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  description = "Security group for private resource access through SSM"
  vpc_id      = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "bastion_https" {
  security_group_id = aws_security_group.bastion_sg.id
  description       = "HTTPS access to AWS Systems Manager endpoints"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_egress_rule" "bastion_to_jenkins" {
  security_group_id            = aws_security_group.bastion_sg.id
  description                  = "Allow Bastion to access private Jenkins UI"
  referenced_security_group_id = aws_security_group.jenkins_sg.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.bastion_ami.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion"
  }
}

output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
