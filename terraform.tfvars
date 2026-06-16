VPCs = [{
  name              = "vpc-public"
  vpc_cidr          = "10.0.0.0/16"
  subnet_cidr       = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  availability_zone = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  enable_igw        = true
  region            = "eu-central-1"
  },
  {
    name              = "vpc-private-1"
    vpc_cidr          = "10.1.0.0/16"
    subnet_cidr       = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
    availability_zone = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
    enable_igw        = false
    region            = "eu-west-1"
  },
  {
    name              = "vpc-private-2"
    vpc_cidr          = "10.2.0.0/16"
    subnet_cidr       = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
    availability_zone = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
    enable_igw        = false
    region            = "eu-west-2"
}]


associate_public_ip_address = true


