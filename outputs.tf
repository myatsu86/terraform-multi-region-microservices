output "bastion_public_ip" {
  value = module.ec2_customer_profile.public_ip
}

output "app_url" {
  value = "http://${module.ec2_customer_profile.public_ip}:9091"
}

output "account_private_ip" {
  value = module.ec2_account.private_ip
}

output "statement_private_ip" {
  value = module.ec2_statement.private_ip
}
