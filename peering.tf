# Cross-region peering cannot be auto-accepted in one step: the connection is
# requested from the requester's region and must be accepted by a separate
# accepter resource in the peer's region. This pattern also works when both
# VPCs are in the same region, so it handles any region mix from tfvars.

# customer-profile (vpc-public) <-> account (vpc-private-1)
resource "aws_vpc_peering_connection" "public_to_private1" {
  region      = local.vpc_region["vpc-public"]
  vpc_id      = module.vpc["vpc-public"].vpc_id
  peer_vpc_id = module.vpc["vpc-private-1"].vpc_id
  peer_region = local.vpc_region["vpc-private-1"]

  tags = { Name = "vpc-public-to-vpc-private-1" }
}

resource "aws_vpc_peering_connection_accepter" "public_to_private1" {
  region                    = local.vpc_region["vpc-private-1"]
  vpc_peering_connection_id = aws_vpc_peering_connection.public_to_private1.id
  auto_accept               = true

  tags = { Name = "vpc-public-to-vpc-private-1" }
}

# account (vpc-private-1) <-> statement (vpc-private-2)
resource "aws_vpc_peering_connection" "private1_to_private2" {
  region      = local.vpc_region["vpc-private-1"]
  vpc_id      = module.vpc["vpc-private-1"].vpc_id
  peer_vpc_id = module.vpc["vpc-private-2"].vpc_id
  peer_region = local.vpc_region["vpc-private-2"]

  tags = { Name = "vpc-private-1-to-vpc-private-2" }
}

resource "aws_vpc_peering_connection_accepter" "private1_to_private2" {
  region                    = local.vpc_region["vpc-private-2"]
  vpc_peering_connection_id = aws_vpc_peering_connection.private1_to_private2.id
  auto_accept               = true

  tags = { Name = "vpc-private-1-to-vpc-private-2" }
}

# vpc-public <-> vpc-private-2 (for Terraform provisioner bastion access to statement-svc)
resource "aws_vpc_peering_connection" "public_to_private2" {
  region      = local.vpc_region["vpc-public"]
  vpc_id      = module.vpc["vpc-public"].vpc_id
  peer_vpc_id = module.vpc["vpc-private-2"].vpc_id
  peer_region = local.vpc_region["vpc-private-2"]

  tags = { Name = "vpc-public-to-vpc-private-2" }
}

resource "aws_vpc_peering_connection_accepter" "public_to_private2" {
  region                    = local.vpc_region["vpc-private-2"]
  vpc_peering_connection_id = aws_vpc_peering_connection.public_to_private2.id
  auto_accept               = true

  tags = { Name = "vpc-public-to-vpc-private-2" }
}

# Routes: each route lives in its own VPC's region. Referencing the accepter's
# connection id ensures routes are only created once the peering is active.

# vpc-public -> vpc-private-1
resource "aws_route" "public_to_private1" {
  region                    = local.vpc_region["vpc-public"]
  route_table_id            = module.vpc["vpc-public"].route_table_id
  destination_cidr_block    = module.vpc["vpc-private-1"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.public_to_private1.vpc_peering_connection_id
}

# vpc-private-1 -> vpc-public
resource "aws_route" "private1_to_public" {
  region                    = local.vpc_region["vpc-private-1"]
  route_table_id            = module.vpc["vpc-private-1"].route_table_id
  destination_cidr_block    = module.vpc["vpc-public"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.public_to_private1.vpc_peering_connection_id
}

# vpc-private-1 -> vpc-private-2
resource "aws_route" "private1_to_private2" {
  region                    = local.vpc_region["vpc-private-1"]
  route_table_id            = module.vpc["vpc-private-1"].route_table_id
  destination_cidr_block    = module.vpc["vpc-private-2"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.private1_to_private2.vpc_peering_connection_id
}

# vpc-private-2 -> vpc-private-1
resource "aws_route" "private2_to_private1" {
  region                    = local.vpc_region["vpc-private-2"]
  route_table_id            = module.vpc["vpc-private-2"].route_table_id
  destination_cidr_block    = module.vpc["vpc-private-1"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.private1_to_private2.vpc_peering_connection_id
}

# vpc-public -> vpc-private-2
resource "aws_route" "public_to_private2" {
  region                    = local.vpc_region["vpc-public"]
  route_table_id            = module.vpc["vpc-public"].route_table_id
  destination_cidr_block    = module.vpc["vpc-private-2"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.public_to_private2.vpc_peering_connection_id
}

# vpc-private-2 -> vpc-public
resource "aws_route" "private2_to_public" {
  region                    = local.vpc_region["vpc-private-2"]
  route_table_id            = module.vpc["vpc-private-2"].route_table_id
  destination_cidr_block    = module.vpc["vpc-public"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.public_to_private2.vpc_peering_connection_id
}
