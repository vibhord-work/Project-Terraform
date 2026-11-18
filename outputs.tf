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
