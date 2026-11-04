output "state_bucket" {
  description = "Tên bucket để điền vào envs/dev/backend.tf"
  value       = aws_s3_bucket.state.bucket
}
