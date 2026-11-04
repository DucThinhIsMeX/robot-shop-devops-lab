# Các node Kubernetes (master và worker), số lượng cố định, IP private cố định.
# Việc cài containerd, kubeadm và dựng cụm do Ansible đảm nhận.
resource "aws_instance" "node" {
  for_each = var.nodes

  ami                    = var.ami_id
  instance_type          = each.value.instance_type
  subnet_id              = var.subnet_id
  private_ip             = each.value.private_ip
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile

  user_data = <<-EOT
    #!/bin/bash
    hostnamectl set-hostname ${each.key}
  EOT

  metadata_options {
    http_tokens = "required"
    # = 2 để pod (EBS CSI driver, External Secrets) đọc được quyền LabRole qua IMDS
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = each.value.volume_size
    encrypted   = true
  }

  tags = {
    Name = "${var.name}-${each.key}"
    Role = each.value.role
  }
}
