# AMI IDs differ per region, so look the image up once per region in use.
data "aws_ami" "ubuntu" {
  for_each = local.regions

  region      = each.value
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_route53_zone" "this" {
  name         = var.hosted_zone
  private_zone = var.private_zone
}

data "aws_acm_certificate" "this" {
  for_each = local.regions
  region   = each.value
  domain   = "*.${var.hosted_zone}"
  statuses = ["ISSUED"]
}
