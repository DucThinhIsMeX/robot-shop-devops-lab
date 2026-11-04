variable "bucket_name" {
  type = string
}

variable "retention_days" {
  description = "Số ngày giữ bản backup"
  type        = number
  default     = 14
}

variable "force_destroy" {
  description = "Cho phép xóa bucket còn dữ liệu khi destroy (phù hợp môi trường lab)"
  type        = bool
  default     = true
}
