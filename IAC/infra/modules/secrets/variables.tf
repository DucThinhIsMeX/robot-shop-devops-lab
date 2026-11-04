variable "prefix" {
  type = string
}

variable "secrets" {
  description = "Tên secret -> tài khoản cần sinh mật khẩu"
  type = map(object({
    username    = string
    description = string
  }))
}
