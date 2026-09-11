# ==============================================================================
# Outputs
# ==============================================================================

output "namespace_name" {
  description = "Tên namespace đã được tạo và quản lý bởi Terraform"
  value       = kubernetes_namespace.robot_shop.metadata[0].name
}

output "quota_max_memory" {
  description = "Mức trần RAM tối đa cho toàn bộ namespace"
  value       = kubernetes_resource_quota.robot_shop_quota.spec[0].hard["limits.memory"]
}

output "quota_max_cpu" {
  description = "Mức trần CPU tối đa cho toàn bộ namespace"
  value       = kubernetes_resource_quota.robot_shop_quota.spec[0].hard["limits.cpu"]
}
