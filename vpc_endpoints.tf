resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.project_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-gateway-endpoint"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
