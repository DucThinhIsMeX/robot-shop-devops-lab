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

output "docker_hub_namespace" {
  description = "Docker Hub account chua image cua he thong"
  value       = var.docker_hub_username
}

output "rancher_url" {
  description = "Giao dien Web Dashboard cua Rancher"
  value       = "https://${aws_instance.rancher.public_ip}/dashboard"
}

output "argocd_url" {
  description = "Giao dien Web Dashboard cua ArgoCD (qua NLB)"
  value       = "https://${module.nlb.dns_name}:30085"
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
