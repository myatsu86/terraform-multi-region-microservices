VPCs = [{
  name               = "vpc-customer-profile"
  vpc_cidr           = "10.0.0.0/16"
  subnet_cidr        = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  availability_zone  = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  enable_igw         = true
  enable_nat_gateway = false
  region             = "eu-central-1"
  },
  {
    name               = "vpc-account"
    vpc_cidr           = "10.1.0.0/16"
    subnet_cidr        = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
    availability_zone  = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    enable_igw         = false
    enable_nat_gateway = true
    region             = "eu-west-1"
  },
  {
    name               = "vpc-statement"
    vpc_cidr           = "10.2.0.0/16"
    subnet_cidr        = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
    availability_zone  = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
    enable_igw         = false
    enable_nat_gateway = true
    region             = "eu-west-2"
}]


associate_public_ip_address = true

hosted_zone        = "myatsumon.info"
private_zone       = false
scaling_target_cpu = 50
account_dns        = "account.myatsumon.info"
statement_dns      = "statement.myatsumon.info"

