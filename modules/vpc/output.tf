output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_ids" {
  # For NAT VPCs, exclude subnet[0] (the NAT GW's public subnet) so ASGs and
  # ALBs only use the private subnets where instances actually run.
  value = var.enable_nat_gateway ? slice(aws_subnet.this[*].id, 1, length(aws_subnet.this)) : aws_subnet.this[*].id
}

output "route_table_id" {
  value = (
    var.enable_nat_gateway ? aws_route_table.nat_private[0].id :
    var.enable_igw ? aws_route_table.this[0].id :
    aws_vpc.this.default_route_table_id
  )
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}
