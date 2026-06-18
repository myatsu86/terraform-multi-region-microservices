variable "VPCs" {
  type = list(object({
    name               = string
    vpc_cidr           = string
    subnet_cidr        = list(string)
    availability_zone  = list(string)
    enable_igw         = bool
    enable_nat_gateway = bool
    region             = string
  }))
}

variable "associate_public_ip_address" {
  type    = bool
  default = false
}

locals {
  # vpc name -> region, e.g. { vpc-public = "eu-central-1", ... }
  vpc_region = { for vpc in var.VPCs : vpc.name => vpc.region }

  # distinct set of regions in use (AMIs and key pairs are per-region)
  regions = toset([for vpc in var.VPCs : vpc.region])
}

variable "hosted_zone" {
  type = string
}

variable "private_zone" {
  type = bool
}

variable "scaling_target_cpu" {
  type = number
}

variable "account_dns" {
  type = string
}

variable "statement_dns" {
  type = string
}
