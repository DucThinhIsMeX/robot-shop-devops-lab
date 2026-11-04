# Edge node: một EC2 nhỏ ở public subnet, kiêm NAT cho private subnet và bastion SSH.
resource "aws_instance" "edge" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  private_ip             = var.private_ip
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile

  # Bắt buộc tắt để chuyển tiếp gói tin của máy khác (NAT)
  source_dest_check = false

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    private_cidr = var.private_subnet_cidr
  })

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = { Name = "${var.name}-edge", Role = "edge" }
}

resource "aws_eip" "edge" {
  domain   = "vpc"
  instance = aws_instance.edge.id
  tags     = { Name = "${var.name}-edge-eip" }
}

# Private subnet ra Internet qua network interface của edge
resource "aws_route" "private_nat" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.edge.primary_network_interface_id
}
