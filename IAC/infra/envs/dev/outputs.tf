output "edge_public_ip" {
  description = "IP public của edge (bastion)"
  value       = module.edge.public_ip
}

output "nlb_dns_name" {
  description = "Địa chỉ truy cập ứng dụng"
  value       = "http://${module.nlb.dns_name}"
}

output "k8s_masters" {
  value = module.k8s_nodes.masters
}

output "k8s_workers" {
  value = module.k8s_nodes.workers
}

output "ecr_registry" {
  value = module.ecr.registry
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

# output "backup_bucket" {
#   value = module.s3_backup.bucket_name
# }

output "secret_names" {
  value = module.secrets.secret_names
}

output "ssh_hint" {
  value = "ssh -F generated/ssh_config k8s-master"
}
