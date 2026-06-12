output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_id" {
  value = aws_subnet.this.id
}

output "route_table_id" {
  value = var.enable_igw ? aws_route_table.this[0].id : aws_vpc.this.default_route_table_id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}
