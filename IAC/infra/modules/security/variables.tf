variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_cidr" {
  type = string
}

variable "admin_cidrs" {
  description = "CIDR được SSH vào edge, ví dụ [\"1.2.3.4/32\"]"
  type        = list(string)
}

variable "ingress_node_ports" {
  description = "NodePort HTTP và HTTPS của ingress controller (Traefik)"
  type        = list(number)
}
