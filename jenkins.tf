data "aws_ssm_parameter" "jenkins_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "jenkins_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins_role" {
  name               = "${var.project_name}-${var.environment}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume_role.json
}

resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "${var.project_name}-${var.environment}-jenkins-profile"
  role = aws_iam_role.jenkins_role.name
}

resource "aws_security_group" "jenkins_sg" {
  name_prefix = "${var.project_name}-${var.environment}-jenkins-"
  description = "Jenkins EC2 security group"
  vpc_id      = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "jenkins_outbound" {
  security_group_id = aws_security_group.jenkins_sg.id
  description       = "Outbound package, GitHub and AWS API access"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.jenkins_ami.value
  instance_type               = "m7i-flex.large"
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.jenkins_profile.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = file("${path.module}/jenkins_user_data.sh")

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins"
  }
}

output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}
