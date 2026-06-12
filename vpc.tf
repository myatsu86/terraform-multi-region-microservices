module "vpc" {
  for_each = { for vpc in var.VPCs : vpc.name => vpc }

  source            = "./modules/vpc"
  name              = each.value.name
  vpc_cidr          = each.value.vpc_cidr
  subnet_cidr       = each.value.subnet_cidr
  availability_zone = each.value.availability_zone
  enable_igw        = each.value.enable_igw
  region            = each.value.region
}
