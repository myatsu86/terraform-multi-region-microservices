# Cross-region peering cannot be auto-accepted in one step: the connection is
# requested from the requester's region and must be accepted by a separate
# accepter resource in the peer's region. This pattern also works when both
# VPCs are in the same region, so it handles any region mix from tfvars.

# customer-profile <-> account
resource "aws_vpc_peering_connection" "customer_profile_to_account" {
  region      = local.vpc_region["vpc-customer-profile"]
  vpc_id      = module.vpc["vpc-customer-profile"].vpc_id
  peer_vpc_id = module.vpc["vpc-account"].vpc_id
  peer_region = local.vpc_region["vpc-account"]

  tags = { Name = "vpc-customer-profile-to-vpc-account" }
}

resource "aws_vpc_peering_connection_accepter" "customer_profile_to_account" {
  region                    = local.vpc_region["vpc-account"]
  vpc_peering_connection_id = aws_vpc_peering_connection.customer_profile_to_account.id
  auto_accept               = true

  tags = { Name = "vpc-customer-profile-to-vpc-account" }
}

# account <-> statement
resource "aws_vpc_peering_connection" "account_to_statement" {
  region      = local.vpc_region["vpc-account"]
  vpc_id      = module.vpc["vpc-account"].vpc_id
  peer_vpc_id = module.vpc["vpc-statement"].vpc_id
  peer_region = local.vpc_region["vpc-statement"]

  tags = { Name = "vpc-account-to-vpc-statement" }
}

resource "aws_vpc_peering_connection_accepter" "account_to_statement" {
  region                    = local.vpc_region["vpc-statement"]
  vpc_peering_connection_id = aws_vpc_peering_connection.account_to_statement.id
  auto_accept               = true

  tags = { Name = "vpc-account-to-vpc-statement" }
}

# customer-profile <-> statement (bastion / direct access)
resource "aws_vpc_peering_connection" "customer_profile_to_statement" {
  region      = local.vpc_region["vpc-customer-profile"]
  vpc_id      = module.vpc["vpc-customer-profile"].vpc_id
  peer_vpc_id = module.vpc["vpc-statement"].vpc_id
  peer_region = local.vpc_region["vpc-statement"]

  tags = { Name = "vpc-customer-profile-to-vpc-statement" }
}

resource "aws_vpc_peering_connection_accepter" "customer_profile_to_statement" {
  region                    = local.vpc_region["vpc-statement"]
  vpc_peering_connection_id = aws_vpc_peering_connection.customer_profile_to_statement.id
  auto_accept               = true

  tags = { Name = "vpc-customer-profile-to-vpc-statement" }
}

# Routes: each route lives in its own VPC's region. Referencing the accepter's
# connection id ensures routes are only created once the peering is active.

# vpc-customer-profile -> vpc-account
resource "aws_route" "customer_profile_to_account" {
  region                    = local.vpc_region["vpc-customer-profile"]
  route_table_id            = module.vpc["vpc-customer-profile"].route_table_id
  destination_cidr_block    = module.vpc["vpc-account"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.customer_profile_to_account.vpc_peering_connection_id
}

# vpc-account -> vpc-customer-profile
resource "aws_route" "account_to_customer_profile" {
  region                    = local.vpc_region["vpc-account"]
  route_table_id            = module.vpc["vpc-account"].route_table_id
  destination_cidr_block    = module.vpc["vpc-customer-profile"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.customer_profile_to_account.vpc_peering_connection_id
}

# vpc-account -> vpc-statement
resource "aws_route" "account_to_statement" {
  region                    = local.vpc_region["vpc-account"]
  route_table_id            = module.vpc["vpc-account"].route_table_id
  destination_cidr_block    = module.vpc["vpc-statement"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.account_to_statement.vpc_peering_connection_id
}

# vpc-statement -> vpc-account
resource "aws_route" "statement_to_account" {
  region                    = local.vpc_region["vpc-statement"]
  route_table_id            = module.vpc["vpc-statement"].route_table_id
  destination_cidr_block    = module.vpc["vpc-account"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.account_to_statement.vpc_peering_connection_id
}

# vpc-customer-profile -> vpc-statement
resource "aws_route" "customer_profile_to_statement" {
  region                    = local.vpc_region["vpc-customer-profile"]
  route_table_id            = module.vpc["vpc-customer-profile"].route_table_id
  destination_cidr_block    = module.vpc["vpc-statement"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.customer_profile_to_statement.vpc_peering_connection_id
}

# vpc-statement -> vpc-customer-profile
resource "aws_route" "statement_to_customer_profile" {
  region                    = local.vpc_region["vpc-statement"]
  route_table_id            = module.vpc["vpc-statement"].route_table_id
  destination_cidr_block    = module.vpc["vpc-customer-profile"].vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.customer_profile_to_statement.vpc_peering_connection_id
}
