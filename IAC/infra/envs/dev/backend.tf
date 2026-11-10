# Lưu trạng thái hạ tầng (terraform.tfstate) ngay tại máy cục bộ
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
