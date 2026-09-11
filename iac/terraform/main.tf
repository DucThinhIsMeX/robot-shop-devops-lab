# ==============================================================================
# Main Infrastructure as Code - Kubernetes Resources
# ==============================================================================

# 1. Khai báo Namespace Robot Shop
# Nếu namespace đã tồn tại, Terraform sẽ quản lý nhãn (labels) và thông tin của nó
resource "kubernetes_namespace" "robot_shop" {
  metadata {
    name = var.namespace_name

    labels = {
      app         = "robot-shop"
      environment = var.environment
      managed_by  = "terraform"
    }

    annotations = {
      description = "Namespace for Instana Robot Shop Microservices Lab"
    }
  }
}

# 2. Khai báo ResourceQuota bảo vệ tài nguyên cụm K8s
resource "kubernetes_resource_quota" "robot_shop_quota" {
  metadata {
    name      = "robot-shop-quota"
    namespace = kubernetes_namespace.robot_shop.metadata[0].name
    labels = {
      managed_by = "terraform"
    }
  }

  spec {
    hard = {
      "requests.cpu"    = "4000m"
      "requests.memory" = "6Gi"
      "limits.cpu"      = var.max_cpu_limit
      "limits.memory"   = var.max_memory_limit
      "pods"            = var.max_pods
    }
  }
}

# 3. Khai báo LimitRange: Tự động gán giới hạn mặc định cho mọi container
resource "kubernetes_limit_range" "robot_shop_limits" {
  metadata {
    name      = "robot-shop-default-limits"
    namespace = kubernetes_namespace.robot_shop.metadata[0].name
    labels = {
      managed_by = "terraform"
    }
  }

  spec {
    limit {
      type = "Container"

      default = {
        cpu    = "500m"
        memory = "512Mi"
      }

      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}
