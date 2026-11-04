variable "region" {
  description = "AWS region (Learner Lab chỉ cho phép us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Tiền tố đặt tên tài nguyên"
  type        = string
  default     = "robot-shop"
}
