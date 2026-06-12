variable "name" {
  type = string
}

variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
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