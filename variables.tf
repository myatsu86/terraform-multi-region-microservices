variable "VPCs" {
  type = list(object({
    name              = string
    vpc_cidr          = string
    subnet_cidr       = string
    availability_zone = string
    enable_igw        = bool
    region            = string
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
