output "vpc_id" {
  description = "Project VPC ID"
  value       = aws_vpc.project_vpc.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = aws_nat_gateway.nat[*].id
}


output "nat_instance_id" {
  description = "NAT instance ID; empty when NAT instance is disabled"
  value       = try(aws_instance.nat_instance[0].id, null)
}

output "nat_instance_public_ip" {
  description = "NAT instance Elastic IP; empty when NAT instance is disabled"
  value       = try(aws_eip.nat_instance[0].public_ip, null)
}


output "mysql_ecs_host_id" {
  description = "Dedicated ECS EC2 host ID for MySQL"
  value       = aws_instance.mysql_ecs_host.id
}

output "mysql_ecs_host_private_ip" {
  description = "Private IP of the dedicated ECS MySQL host"
  value       = aws_instance.mysql_ecs_host.private_ip
}

output "mysql_service_dns" {
  description = "Private Cloud Map DNS name for the ECS MySQL service"
  value       = "mysql.db.internal"
}

output "mysql_data_volume_id" {
  description = "Persistent encrypted EBS volume ID for MySQL data"
  value       = aws_ebs_volume.mysql_data.id
}

output "ecs_mysql_credentials_secret_arn" {
  description = "Secrets Manager ARN for ECS MySQL credentials (not the secret values)"
  value       = aws_secretsmanager_secret.ecs_mysql_credentials.arn
}
