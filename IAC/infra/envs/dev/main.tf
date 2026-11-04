data "aws_caller_identity" "current" {}

# Ubuntu Server 24.04 LTS mới nhất của Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Learner Lab không cho tạo IAM role: dùng instance profile có sẵn
data "aws_iam_instance_profile" "lab" {
  name = var.instance_profile_name
}

locals {
  name = "${var.project}-${var.environment}"

  ingress_listeners = {
    http  = { port = 80, node_port = var.ingress_http_node_port }
    https = { port = 443, node_port = var.ingress_https_node_port }
  }
}

module "network" {
  source = "../../modules/network"

  name                = local.name
  region              = var.region
  az                  = var.az
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

module "security" {
  source = "../../modules/security"

  name                = local.name
  vpc_id              = module.network.vpc_id
  private_subnet_cidr = module.network.private_subnet_cidr
  admin_cidrs         = var.admin_cidrs
  ingress_node_ports  = [var.ingress_http_node_port, var.ingress_https_node_port]
}

module "edge" {
  source = "../../modules/edge"

  name                   = local.name
  ami_id                 = data.aws_ami.ubuntu.id
  instance_type          = var.edge_instance_type
  subnet_id              = module.network.public_subnet_id
  private_ip             = var.edge_private_ip
  security_group_id      = module.security.edge_sg_id
  key_name               = var.key_name
  instance_profile       = data.aws_iam_instance_profile.lab.name
  private_subnet_cidr    = module.network.private_subnet_cidr
  private_route_table_id = module.network.private_route_table_id
}

module "k8s_nodes" {
  source = "../../modules/k8s-nodes"

  name              = local.name
  ami_id            = data.aws_ami.ubuntu.id
  subnet_id         = module.network.private_subnet_id
  security_group_id = module.security.k8s_sg_id
  key_name          = var.key_name
  instance_profile  = data.aws_iam_instance_profile.lab.name
  nodes             = var.k8s_nodes

  # Node cần NAT để tải gói ngay từ lần khởi động đầu
  depends_on = [module.edge]
}

module "nlb" {
  source = "../../modules/nlb"

  name                = local.name
  vpc_id              = module.network.vpc_id
  subnet_id           = module.network.public_subnet_id
  security_group_id   = module.security.nlb_sg_id
  worker_instance_ids = module.k8s_nodes.worker_instance_ids
  listeners           = local.ingress_listeners
}

module "ecr" {
  source = "../../modules/ecr"

  prefix       = var.project
  repositories = var.ecr_repositories
}

module "s3_backup" {
  source = "../../modules/s3-backup"

  bucket_name = "${local.name}-backup-${data.aws_caller_identity.current.account_id}"
}

module "secrets" {
  source = "../../modules/secrets"

  prefix  = local.name
  secrets = var.app_secrets
}

# Sinh inventory và ssh config cho Ansible
resource "local_file" "ansible_inventory" {
  filename        = "${path.root}/generated/inventory.ini"
  file_permission = "0644"
  content = templatefile("${path.root}/templates/inventory.ini.tftpl", {
    edge_public_ip = module.edge.public_ip
    masters        = module.k8s_nodes.masters
    workers        = module.k8s_nodes.workers
    ssh_user       = var.ssh_user
    ssh_key_path   = var.ssh_private_key_path
  })
}

resource "local_file" "ssh_config" {
  filename        = "${path.root}/generated/ssh_config"
  file_permission = "0644"
  content = templatefile("${path.root}/templates/ssh_config.tftpl", {
    edge_public_ip = module.edge.public_ip
    nodes          = merge(module.k8s_nodes.masters, module.k8s_nodes.workers)
    ssh_user       = var.ssh_user
    ssh_key_path   = var.ssh_private_key_path
  })
}
