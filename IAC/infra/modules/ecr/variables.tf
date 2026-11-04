variable "prefix" {
  description = "Tiền tố tên repository, ví dụ robot-shop"
  type        = string
}

variable "repositories" {
  description = "Danh sách tên image"
  type        = list(string)
}

variable "keep_images" {
  description = "Số image giữ lại mỗi repository"
  type        = number
  default     = 15
}

variable "force_delete" {
  description = "Cho phép xóa repository còn image khi destroy (phù hợp môi trường lab)"
  type        = bool
  default     = true
}
