resource "aws_route_table" "public" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.project_igw.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt-${count.index}"
  }
}

resource "aws_route" "private_egress" {
  count = (var.enable_nat_gateway || var.enable_nat_instance) ? length(var.private_subnet_cidrs) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"

  # Keep the NAT Gateway active during the first NAT-instance deployment.
  # Switch this flag only after the NAT instance has passed connectivity tests.
  nat_gateway_id = var.route_private_traffic_through_nat_instance ? null : aws_nat_gateway.nat[
    var.single_nat_gateway ? 0 : count.index
  ].id

  instance_id = var.route_private_traffic_through_nat_instance ? aws_instance.nat_instance[0].id : null
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
