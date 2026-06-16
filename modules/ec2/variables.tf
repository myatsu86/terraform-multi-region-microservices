variable "name" {
  type = string
}

variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "user_data" {
  type = string
}

variable "key_name" {
  type = string
}

variable "associate_public_ip_address" {
  type    = bool
  default = false
}

variable "service_port" {
  type = number
}

variable "region" {
  type = string
}

variable "min_size" {
  type    = number
  default = 3
}

variable "max_size" {
  type    = number
  default = 5
}

variable "desired_capacity" {
  type    = number
  default = 3
}

variable "target_group_arns" {
  type    = list(string)
  default = []
}

variable "iam_instance_profile_arn" {
  type = string
}

