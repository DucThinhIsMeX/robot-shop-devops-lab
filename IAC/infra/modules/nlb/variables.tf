variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "worker_instance_ids" {
  description = "Tên worker -> instance id"
  type        = map(string)
}

variable "listeners" {
  description = "Tên -> cổng NLB và NodePort tương ứng"
  type = map(object({
    port      = number
    node_port = number
  }))
}
