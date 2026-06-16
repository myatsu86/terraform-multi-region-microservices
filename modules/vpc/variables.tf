variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = list(string)
}

variable "availability_zone" {
  type = list(string)
}

variable "enable_igw" {
  type    = bool
  default = false
}