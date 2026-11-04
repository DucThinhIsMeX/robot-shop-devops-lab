# State lưu trên S3 (tạo bằng thư mục bootstrap), khóa bằng file .tflock trên S3.
# Cấu hình chi tiết nằm trong backend.hcl:
#   terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {}
}
