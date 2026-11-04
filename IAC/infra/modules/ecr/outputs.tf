output "repository_urls" {
  value = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "registry" {
  description = "Địa chỉ registry để docker login"
  value       = split("/", values(aws_ecr_repository.this)[0].repository_url)[0]
}
