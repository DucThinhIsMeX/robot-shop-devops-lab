# ==============================================================================
# Terraform Provider Configuration for Kubernetes
# ==============================================================================

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30.0"
    }
  }
}

# Cấu hình kết nối tới cụm Kubernetes
# Sử dụng trực tiếp kubeconfig của node master hoặc file ~/.kube/config
provider "kubernetes" {
  config_path = "~/.kube/config"
}
