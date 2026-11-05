# ☸️ Kubernetes Manifests (Tự xây dựng thủ công)

Thư mục này chứa toàn bộ các file manifest Kubernetes được xây dựng thủ công từ con số 0 cho dự án **Stan's Robot Shop**, thay thế cho Helm Chart cũ để tăng tính tự chủ, tối ưu tài nguyên và kiểm soát chi tiết từng dịch vụ.

---

## 📂 Cấu trúc thư mục

```plaintext
k8s/
├── 00-namespace.yaml          # Tạo namespace robot-shop
├── 01-configs/                # Cấu hình biến môi trường & bí mật
│   ├── configmap.yaml         # Hostnames, MongoDB URLs, Redis, MySQL, RabbitMQ
│   └── secret.yaml            # Mật khẩu DB và tài khoản RabbitMQ
├── 02-datastores/             # Tầng dữ liệu & Hàng đợi
│   ├── mongodb.yaml           # Deployment + Service (Port 27017)
│   ├── redis.yaml             # StatefulSet + PVC (local-path) + Service (Port 6379)
│   ├── mysql.yaml             # Deployment + Service (Port 3306)
│   └── rabbitmq.yaml          # Deployment + Service (AMQP 5672, Management 15672)
├── 03-microservices/          # 7 dịch vụ nghiệp vụ
│   ├── catalogue.yaml         # Node.js Express (Port 8080)
│   ├── cart.yaml              # Node.js Express (Port 8080)
│   ├── user.yaml              # Node.js Express (Port 8080)
│   ├── shipping.yaml          # Java Spring Boot (Port 8080)
│   ├── ratings.yaml           # PHP Apache (Port 80)
│   ├── payment.yaml           # Python Flask (Port 8080)
│   └── dispatch.yaml          # Go Background Worker (Không mở cổng)
├── 04-gateway/                # Tầng cổng vào
│   └── web.yaml               # Nginx Gateway + NodePort 30080
└── 05-ingress/                # Tầng Ingress Controller
    └── ingress.yaml           # Điều phối Ingress Nginx Controller
```

---

## 🚀 Hướng dẫn triển khai từng bước

Bạn có thể triển khai lần lượt từng tầng để theo dõi tiến trình khởi tạo:

```bash
# 1. Tạo Namespace
kubectl apply -f k8s/00-namespace.yaml

# 2. Tạo ConfigMap và Secret
kubectl apply -f k8s/01-configs/

# 3. Khởi tạo tầng cơ sở dữ liệu và hàng đợi
kubectl apply -f k8s/02-datastores/

# 4. Khởi tạo 7 Microservices
kubectl apply -f k8s/03-microservices/

# 5. Khởi tạo Web Gateway
kubectl apply -f k8s/04-gateway/

# 6. Cấu hình Ingress (Tùy chọn nếu đã cài Ingress Nginx Controller)
kubectl apply -f k8s/05-ingress/
```

Hoặc **triển khai toàn bộ cụm chỉ bằng 1 lệnh duy nhất**:
```bash
kubectl apply -R -f k8s/
```

---

## 🔍 Kiểm tra trạng thái

```bash
# Xem toàn bộ Pods trong namespace
kubectl get pods -n robot-shop -w

# Xem toàn bộ Services
kubectl get svc -n robot-shop
```

---

## 🌐 Truy cập ứng dụng

- **Truy cập trực tiếp qua NodePort:**  
  Mở trình duyệt: `http://<IP_WORKER>:30080`
- **Truy cập qua NLB AWS (nếu chạy trên AWS):**  
  Mở trình duyệt: `http://<NLB_DNS_NAME>`

---

## 🧹 Dọn dẹp cụm

Xóa sạch toàn bộ tài nguyên bằng cách xóa namespace:
```bash
kubectl delete -f k8s/00-namespace.yaml
```

