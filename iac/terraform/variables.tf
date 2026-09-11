# ==============================================================================
# Variables Definition
# ==============================================================================

variable "namespace_name" {
  description = "Tên namespace dành cho dự án Robot Shop"
  type        = string
  default     = "robot-shop"
}

variable "environment" {
  description = "Môi trường triển khai (prod, staging, lab)"
  type        = string
  default     = "lab"
}

variable "max_cpu_limit" {
  description = "Giới hạn trần tổng CPU cho toàn bộ namespace"
  type        = string
  default     = "6000m" # Tương đương 6 Cores
}

variable "max_memory_limit" {
  description = "Giới hạn trần tổng RAM cho toàn bộ namespace"
  type        = string
  default     = "8Gi"   # Tối đa 8GB RAM bảo vệ laptop
}

variable "max_pods" {
  description = "Số lượng Pod tối đa được phép chạy cùng lúc trong namespace"
  type        = string
  default     = "30"
}
