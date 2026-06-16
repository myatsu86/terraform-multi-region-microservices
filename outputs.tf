# output "bastion_public_ip" {
#   value = module.ec2_customer_profile.public_ip
# }

# output "app_url" {
#   value = "http://${module.ec2_customer_profile.public_ip}:9091"
# }

# output "account_private_ip" {
#   value = module.ec2_account.private_ip
# }

# output "statement_private_ip" {
#   value = module.ec2_statement.private_ip
# }

output "app_url" {
  value = "http://${aws_lb.customer_profile_alb.dns_name}"
}

output "account_alb_dns" {
  value = aws_lb.account_alb.dns_name
}

output "statement_alb_dns" {
  value = aws_lb.statement_alb.dns_name
}

output "customer_profile_asg_name" {
  value = module.ec2_customer_profile.asg_name
}

output "account_asg_name" {
  value = module.ec2_account.asg_name
}

output "statement_asg_name" {
  value = module.ec2_statement.asg_name
}


