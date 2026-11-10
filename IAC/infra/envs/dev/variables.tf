variable "project" {
  type    = string
  default = "robot-shop"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  description = "Learner Lab chỉ cho phép us-east-1"
  type        = string
  default     = "us-east-1"
}

variable "az" {
  type    = string
  default = "us-east-1a"
}

# ---------- Mạng ----------
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.11.0/24"
}

variable "admin_cidrs" {
  description = "IP public của bạn dạng /32, được phép SSH vào edge"
  type        = list(string)

  validation {
    condition     = !contains(var.admin_cidrs, "0.0.0.0/0")
    error_message = "Không mở SSH cho toàn Internet."
  }
}

# ---------- Máy chủ ----------
variable "key_name" {
  description = "Key pair có sẵn trong Learner Lab"
  type        = string
  default     = "vockey"
}

variable "instance_profile_name" {
  description = "Instance profile có sẵn trong Learner Lab"
  type        = string
  default     = "LabInstanceProfile"
}

variable "edge_instance_type" {
  type    = string
  default = "t3.small"
}

variable "edge_private_ip" {
  type    = string
  default = "10.0.1.10"
}

variable "k8s_nodes" {
  description = "Các node Kubernetes. Tên node cũng là hostname"
  type = map(object({
    role          = string
    instance_type = string
    private_ip    = string
    volume_size   = number
  }))
  default = {
    k8s-master   = { role = "master", instance_type = "t3.medium", private_ip = "10.0.11.10", volume_size = 30 }
    k8s-worker-1 = { role = "worker", instance_type = "t3.large", private_ip = "10.0.11.21", volume_size = 40 }
    k8s-worker-2 = { role = "worker", instance_type = "t3.large", private_ip = "10.0.11.22", volume_size = 40 }
  }
}

# ---------- Ingress ----------
variable "ingress_http_node_port" {
  description = "NodePort HTTP của Traefik, phải khớp group_vars của Ansible"
  type        = number
  default     = 30080
}

variable "ingress_https_node_port" {
  description = "NodePort HTTPS của Traefik"
  type        = number
  default     = 30443
}

# ---------- Registry và secret ----------
variable "ecr_repositories" {
  description = "8 service cùng 2 image dữ liệu của Robot Shop"
  type        = list(string)
  default     = ["web", "catalogue", "cart", "user", "shipping", "ratings", "payment", "dispatch", "mongo", "mysql"]
}

variable "app_secrets" {
  description = "Tài khoản cơ sở dữ liệu và hàng đợi cần sinh mật khẩu"
  type = map(object({
    username    = string
    description = string
  }))
  default = {
    mongodb        = { username = "admin", description = "Tai khoan quan tri MongoDB" }
    mysql-root     = { username = "root", description = "Tai khoan root MySQL" }
    mysql-shipping = { username = "shipping", description = "Tai khoan MySQL cua service shipping" }
    mysql-ratings  = { username = "ratings", description = "Tai khoan MySQL cua service ratings" }
    rabbitmq       = { username = "robotshop", description = "Tai khoan RabbitMQ cua payment va dispatch" }
  }
}

# ---------- Ansible ----------
variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Đường dẫn file khóa tải từ Learner Lab (labsuser.pem)"
  type        = string
  default     = "~/.ssh/labsuser.pem"
}
