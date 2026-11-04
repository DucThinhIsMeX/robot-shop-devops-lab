output "public_ip" {
  value = aws_eip.edge.public_ip
}

output "private_ip" {
  value = aws_instance.edge.private_ip
}

output "instance_id" {
  value = aws_instance.edge.id
}
