output "masters" {
  description = "Tên -> IP private của master"
  value       = { for k, n in aws_instance.node : k => n.private_ip if var.nodes[k].role == "master" }
}

output "workers" {
  description = "Tên -> IP private của worker"
  value       = { for k, n in aws_instance.node : k => n.private_ip if var.nodes[k].role == "worker" }
}

output "worker_instance_ids" {
  description = "Tên -> instance id của worker, dùng gắn vào target group NLB"
  value       = { for k, n in aws_instance.node : k => n.id if var.nodes[k].role == "worker" }
}
