output "edge_sg_id" {
  value = aws_security_group.edge.id
}

output "nlb_sg_id" {
  value = aws_security_group.nlb.id
}

output "k8s_sg_id" {
  value = aws_security_group.k8s.id
}
