# output "private_ip" {
#   value = aws_instance.this.private_ip
# }

# output "public_ip" {
#   value = aws_instance.this.public_ip
# }

# output "instance_id" {
#   value = aws_instance.this.id
# }

# output "security_group_id" {
#   value = aws_security_group.this.id
# }

output "security_group_id" {
  value = aws_security_group.this.id
}

output "asg_name" {
  value = aws_autoscaling_group.this.name
}
