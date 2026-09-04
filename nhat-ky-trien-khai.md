# NHẬT KÝ TRIỂN KHAI DỰ ÁN DEVOPS: ROBOT SHOP

Tài liệu này ghi chú chi tiết từng bước đã thực hiện, các quyết định kỹ thuật và trạng thái của hệ thống theo từng giai đoạn.

---

## GIAI ĐOẠN 0: CỦNG CỐ NỀN TẢNG CỤM KUBERNETES

- **Thời gian thực hiện:** 03/09/2026
- **Môi trường:** On-premise VMware Workstation (VMnet8)
  - `192.168.180.101`: `k8s-master-1` (control-plane, v1.30.14, containerd 2.2.1)
  - `192.168.180.102`: `k8s-master-2` (worker node)
  - `192.168.180.103`: `k8s-master-3` (worker node)
  - `192.168.180.104`: `rancher-server` (quản trị web)

### 1. Khảo sát hiện trạng ban đầu
- **Node Status:** Cả 3 node đều ở trạng thái `Ready`.
- **Hạ tầng mạng (CNI):** Calico (`calico-node`, `calico-kube-controllers`) hoạt động bình thường trên tất cả các node.
- **DNS nội bộ:** CoreDNS hoạt động bình thường (`2/2 Running`).
- **Ingress Controller:** Đã có sẵn `ingress-nginx-controller` hoạt động trong namespace `ingress-nginx`.
- **Lưu trữ (Storage):** Chưa có `StorageClass` nào trong cụm (`No resources found`).

### 2. Các hành động đã thực hiện
- **Lựa chọn giải pháp lưu trữ:** Chọn giải pháp **Dynamic Provisioning** với `local-path-provisioner` thay vì tạo PersistentVolume thủ công qua giao diện Rancher, nhằm đảm bảo tuân thủ nguyên tắc tự động hóa của GitOps (ArgoCD/Helm).
- **Cài đặt Rancher Local Path Provisioner:**
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml
  ```
- **Đặt làm StorageClass mặc định của cụm:**
  ```bash
  kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
  ```
- **Xác nhận kết quả:** Cụm đã có StorageClass `local-path` là default. Khi cài đặt các dịch vụ cần lưu trữ dữ liệu (StatefulSet / PVC của MySQL, MongoDB ở Robot Shop), PV sẽ được tự động cấp phát trên node.

### 3. Đánh giá hoàn thành Giai đoạn 0
- [x] 3 node `Ready`
- [x] Ingress controller `Running` (`ingress-nginx`)
- [x] StorageClass mặc định sẵn sàng (`local-path`)
- [x] Cụm đủ điều kiện để triển khai các workload microservice có stateful (Database).

---

## GIAI ĐOẠN 1: TRIỂN KHAI ROBOT SHOP THỦ CÔNG (BASELINE)

- **Thời gian thực hiện:** 03/09/2026
- **Mục tiêu:** Dựng ứng dụng làm mốc chuẩn (baseline), nắm rõ kiến trúc microservices và xác nhận khả năng vận hành của cụm K8s.

### 1. Các bước thực hiện
- Tạo namespace: `kubectl create namespace robot-shop`
- Triển khai toàn bộ ứng dụng qua Helm chart với cờ NodePort:
  ```bash
  helm install robot-shop --namespace robot-shop --set nodeport=true .
  ```

### 2. Sự cố phát sinh & Cách xử lý (Troubleshooting)
- **Hiện tượng:** 11/12 Pod chuyển sang `Running`, riêng `redis-0` (StatefulSet) bị kẹt ở trạng thái `Pending`. PVC `data-redis-0` báo lỗi không gán được đĩa.
- **Nguyên nhân:** File `values.yaml` của Helm chart Robot Shop gán cứng cấu hình `redis.storageClassName: standard`, trong khi StorageClass mặc định của cụm là `local-path`.
- **Giải pháp:** Tạo thêm một StorageClass alias có tên `standard` trỏ cùng vào provisioner `rancher.io/local-path`:
  ```bash
  cat <<EOF | kubectl apply -f -
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: standard
  provisioner: rancher.io/local-path
  volumeBindingMode: WaitForFirstConsumer
  reclaimPolicy: Delete
  EOF
  ```
- **Kết quả:** Ngay sau khi apply, `data-redis-0` tự động `Bound`, pod `redis-0` chuyển sang `Running`. Toàn bộ 12/12 pod đều `Running` ổn định.

### 3. Kiểm thử ứng dụng
- Service `web` chạy ở NodePort `32100`.
- Truy cập trình duyệt qua `http://192.168.180.102:32100`.
- Kiểm thử luồng nghiệp vụ: Duyệt danh mục sản phẩm (Catalogue -> MongoDB), thêm hàng vào giỏ (Cart -> Redis), xác nhận đơn hàng thành công.

### 4. Đánh giá hoàn thành Giai đoạn 1
- [x] Mọi pod (12/12) `Running`.
- [x] Đã truy cập web và đặt đơn hàng thành công trên browser.
- [x] Xác lập xong "mốc chuẩn" (baseline) để chuẩn bị cho giai đoạn tự động hóa CI/CD & GitOps.

---

## GIAI ĐOẠN 2: SOURCE CONTROL (GITLAB)

- **Thời gian thực hiện:** 04/09/2026
- **Mục tiêu:** Đưa mã nguồn vào quản lý phiên bản trên GitLab on-premise, tách biệt Code Repo và Config Repo theo chuẩn GitOps.

### 1. Các bước thực hiện
- Khởi động máy ảo `gitlab-server` (`192.168.180.51`).
- Tạo và đẩy mã nguồn vào 2 repository riêng biệt:
  - **`robot-shop`:** Chứa toàn bộ source code của các microservice và Dockerfile.
  - **`robot-shop-deploy`:** Tách riêng thư mục Helm chart (`Chart.yaml`, `values.yaml`, `templates/`) để phục vụ việc đồng bộ tự động của ArgoCD sau này.
- Kích hoạt và xác nhận tính năng **Container Registry** tích hợp sẵn của GitLab trên cổng registry.

### 2. Đánh giá hoàn thành Giai đoạn 2
- [x] 2 repository tách biệt hoạt động tốt trên GitLab.
- [x] Code và Helm manifest đã được push đầy đủ.
- [x] GitLab Container Registry sẵn sàng cho giai đoạn CI pipeline (GĐ3).

---

## GIAI ĐOẠN 3: CI PIPELINE (BUILD - TEST - SCAN - PUSH)
*(Đang chuẩn bị thực hiện)*
