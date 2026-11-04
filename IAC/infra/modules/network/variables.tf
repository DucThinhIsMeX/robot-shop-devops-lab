variable "name" {
  description = "Tiền tố đặt tên"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "az" {
  description = "Availability Zone duy nhất"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR của VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR public subnet"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR private subnet"
  type        = string
}
