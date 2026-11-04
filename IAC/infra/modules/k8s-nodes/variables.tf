variable "name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "instance_profile" {
  type = string
}

variable "nodes" {
  description = "Map tên node -> cấu hình. role là master hoặc worker"
  type = map(object({
    role          = string
    instance_type = string
    private_ip    = string
    volume_size   = number
  }))

  validation {
    condition     = alltrue([for n in values(var.nodes) : contains(["master", "worker"], n.role)])
    error_message = "role chỉ nhận master hoặc worker."
  }

  validation {
    condition     = length([for n in values(var.nodes) : n if n.role == "master"]) == 1
    error_message = "Cần đúng một node master."
  }
}
