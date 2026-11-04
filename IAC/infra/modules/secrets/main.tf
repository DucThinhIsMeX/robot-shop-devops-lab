# Sinh mật khẩu ngẫu nhiên và lưu vào Secrets Manager.
# Pod đọc qua External Secrets Operator. Mật khẩu nằm trong Terraform state,
# vì vậy state bucket phải bật mã hóa và chặn truy cập công khai.
resource "random_password" "this" {
  for_each = var.secrets

  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name                    = "${var.prefix}/${each.key}"
  description             = each.value.description
  recovery_window_in_days = 0 # xóa ngay khi destroy, tránh trùng tên khi dựng lại
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = var.secrets

  secret_id = aws_secretsmanager_secret.this[each.key].id
  secret_string = jsonencode({
    username = each.value.username
    password = random_password.this[each.key].result
  })
}
