module "ec2_statement" {
  source        = "./modules/ec2"
  name          = "statement-svc"
  region        = local.vpc_region["vpc-statement"]
  ami           = data.aws_ami.ubuntu[local.vpc_region["vpc-statement"]].id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.this[local.vpc_region["vpc-statement"]].key_name
  subnet_ids    = module.vpc["vpc-statement"].subnet_ids
  vpc_id        = module.vpc["vpc-statement"].vpc_id
  service_port  = 9093
  user_data     = file("${path.module}/scripts/statement.sh")

  target_group_arns  = [aws_lb_target_group.statement_tg.arn]
  scaling_target_cpu = var.scaling_target_cpu
}

module "ec2_account" {
  source        = "./modules/ec2"
  name          = "account-svc"
  region        = local.vpc_region["vpc-account"]
  ami           = data.aws_ami.ubuntu[local.vpc_region["vpc-account"]].id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.this[local.vpc_region["vpc-account"]].key_name
  subnet_ids    = module.vpc["vpc-account"].subnet_ids
  vpc_id        = module.vpc["vpc-account"].vpc_id
  service_port  = 9092
  user_data = templatefile("${path.module}/scripts/account.sh", {
    upstream_uri = var.statement_dns
  })

  target_group_arns  = [aws_lb_target_group.account_tg.arn]
  scaling_target_cpu = var.scaling_target_cpu
}

module "ec2_customer_profile" {
  source                      = "./modules/ec2"
  name                        = "customer-profile-svc"
  region                      = local.vpc_region["vpc-customer-profile"]
  ami                         = data.aws_ami.ubuntu[local.vpc_region["vpc-customer-profile"]].id
  associate_public_ip_address = var.associate_public_ip_address
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.this[local.vpc_region["vpc-customer-profile"]].key_name
  subnet_ids                  = module.vpc["vpc-customer-profile"].subnet_ids
  vpc_id                      = module.vpc["vpc-customer-profile"].vpc_id
  service_port                = 9091
  user_data = templatefile("${path.module}/scripts/user-profile.sh", {
    upstream_uri = var.account_dns
  })

  target_group_arns  = [aws_lb_target_group.customer_profile_tg.arn]
  scaling_target_cpu = var.scaling_target_cpu
}
