module "ec2_statement" {
  source        = "./modules/ec2"
  name          = "statement-svc"
  region        = local.vpc_region["vpc-private-2"]
  ami           = data.aws_ami.ubuntu[local.vpc_region["vpc-private-2"]].id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.this[local.vpc_region["vpc-private-2"]].key_name
  subnet_id     = module.vpc["vpc-private-2"].subnet_id
  vpc_id        = module.vpc["vpc-private-2"].vpc_id
  service_port  = 9093
  user_data     = file("${path.module}/scripts/statement.sh")
}

module "ec2_account" {
  source        = "./modules/ec2"
  name          = "account-svc"
  region        = local.vpc_region["vpc-private-1"]
  ami           = data.aws_ami.ubuntu[local.vpc_region["vpc-private-1"]].id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.this[local.vpc_region["vpc-private-1"]].key_name
  subnet_id     = module.vpc["vpc-private-1"].subnet_id
  vpc_id        = module.vpc["vpc-private-1"].vpc_id
  service_port  = 9092
  user_data = templatefile("${path.module}/scripts/account.sh", {
    upstream_ip = module.ec2_statement.private_ip
  })
}

module "ec2_customer_profile" {
  source                      = "./modules/ec2"
  name                        = "customer-profile-svc"
  region                      = local.vpc_region["vpc-public"]
  ami                         = data.aws_ami.ubuntu[local.vpc_region["vpc-public"]].id
  associate_public_ip_address = var.associate_public_ip_address
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.this[local.vpc_region["vpc-public"]].key_name
  subnet_id                   = module.vpc["vpc-public"].subnet_id
  vpc_id                      = module.vpc["vpc-public"].vpc_id
  service_port                = 9091
  user_data = templatefile("${path.module}/scripts/user-profile.sh", {
    upstream_ip = module.ec2_account.private_ip
  })
}
