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

- **Thời gian thực hiện:** 04/09/2026
- **Mục tiêu:** Xây dựng quy trình tích hợp liên tục (CI) tự động theo chuẩn DevSecOps: Test -> Quét lỗ hổng Trivy -> Build Docker Image -> Push lên Container Registry với tag Commit SHA.

### 1. Các thành phần hạ tầng đã thiết lập
- **GitLab Runner:**
  - Cài đặt trực tiếp trên máy ảo `gitlab-server` (`192.168.180.51`).
  - Executor: `docker` (sử dụng base image `docker:latest`).
  - Cấu hình socket binding: Mount `/var/run/docker.sock:/var/run/docker.sock` để runner giao tiếp trực tiếp với Docker Engine máy chủ.
  - Cấu hình mạng: Khai báo `extra_hosts = ["gitlab.ducthinh.com:192.168.180.51"]` để các container runner phân giải được domain nội bộ.
- **GitLab Container Registry:**
  - Kích hoạt trên cổng `5050` (`registry_external_url 'http://gitlab.ducthinh.com:5050'`).
  - Cấu hình `/etc/docker/daemon.json` chấp nhận insecure HTTP registry.
  - Bật tính năng Container Registry trong cấu hình Visibility của project `robot-shop`.

### 2. Thiết kế và Tinh chỉnh Pipeline (`.gitlab-ci.yml`)
- **Stage 1 (Test):** Sử dụng image `node:14-alpine`, chạy `node -c server.js` để kiểm tra cú pháp nhanh và toàn vẹn trước khi build.
- **Stage 2 (Scan - DevSecOps Shift-Left):** Sử dụng `aquasec/trivy:latest` để tự động quét toàn bộ thư viện dependencies, phát hiện các lỗ hổng bảo mật mức `HIGH` và `CRITICAL`.
- **Stage 3 (Build & Push):** Sử dụng `docker:latest`, tự động xác thực bằng biến môi trường `$CI_REGISTRY_USER` và `$CI_JOB_TOKEN`, đóng gói image với tag Commit SHA (`$CI_COMMIT_SHORT_SHA`) và tag `latest`, sau đó đẩy trực tiếp lên GitLab Container Registry.

### 3. Sự cố phát sinh & Khắc phục
- **Lỗi API Docker Client cũ:** Ban đầu sử dụng `image: docker:24.0.5` (API v1.43) không tương thích với Docker daemon mới của host (yêu cầu API >= 1.44). Đã khắc phục bằng cách nâng cấp lên `docker:latest`.
- **Lỗi cú pháp YAML:** Dấu hai chấm `:` trong chuỗi `echo` gây hiểu nhầm sang cặp key-value dictionary. Đã làm sạch và chuẩn hóa toàn bộ file CI.

### 4. Đánh giá hoàn thành Giai đoạn 3
- [x] Pipeline chạy xanh toàn bộ (Passed) 3/3 jobs.
- [x] Image `cart` xuất hiện trên GitLab Container Registry với tag Commit SHA rõ ràng.
- [x] Khép kín vòng đời CI, sẵn sàng chuyển sang Giai đoạn 4: GitOps Continuous Delivery với ArgoCD.

---

## GIAI ĐOẠN 4: GITOPS CD (ARGOCD)

- **Thời gian thực hiện:** 06/09/2026
- **Mục tiêu:** Thiết lập quy trình phân phối liên tục (CD) theo chuẩn GitOps với ArgoCD. Git là nguồn chân lý duy nhất (Single Source of Truth), loại bỏ hoàn toàn việc gõ lệnh `helm` hoặc `kubectl` thủ công.

### 1. Triển khai ArgoCD
- Dọn dẹp bản cài đặt thủ công ở Giai đoạn 1 (`helm uninstall robot-shop -n robot-shop`).
- Cài đặt ArgoCD vào cụm Kubernetes trong namespace `argocd`.
- Mở cổng truy cập Web UI của `argocd-server` bằng phương thức `NodePort`.
- Lấy và giải mã mật khẩu khởi tạo từ secret `argocd-initial-admin-secret`.

### 2. Kết nối Kho cấu hình GitOps (`robot-shop-deploy`)
- **Sự cố phát sinh (DNS CoreDNS):** Khi trỏ URL bằng domain nội bộ `http://gitlab.ducthinh.com/...`, Pod ArgoCD báo lỗi `dial tcp: lookup gitlab.ducthinh.com on 10.96.0.10:53: no such host` do CoreDNS nội bộ không biết domain host ảo.
- **Giải pháp:** Cấu hình trỏ trực tiếp bằng IP máy ảo GitLab `http://192.168.180.51/robot-shop-group/robot-shop-deploy.git`. Kết nối chuyển sang `Successful` ngay lập tức.

### 3. Khởi tạo ArgoCD Application & Vận hành Tự động
- Tạo ứng dụng `robot-shop` với chế độ đồng bộ:
  - **`Auto-Sync`:** Tự động lắng nghe thay đổi trên nhánh `main` của repo deploy.
  - **`Prune Resources`:** Tự động dọn dẹp các tài nguyên thừa.
  - **`Self-Heal`:** Tự động khôi phục cấu hình khi có can thiệp thủ công từ ngoài cụm.
- ArgoCD đồng bộ toàn bộ hơn 10 microservices, chuyển sang trạng thái `Synced` và `Healthy`.

### 4. Kiểm chứng Vòng lặp GitOps (GitOps Loop Validation)
- Thay đổi số lượng `replicas: 2` trực tiếp trong file `cart-deployment.yaml` trên repo `robot-shop-deploy` ở GitLab và commit.
- ArgoCD tự động phát hiện commit mới từ Git và scale pod của service `cart` lên 2 pod mà không cần bất kỳ lệnh thao tác tay nào trên cụm.

### 5. Đánh giá hoàn thành Giai đoạn 4
- [x] ArgoCD hiển thị toàn bộ app `Synced` + `Healthy`.
- [x] Sửa Git → cụm Kubernetes tự động đồng bộ theo thời gian thực.
- [x] Cơ chế Self-healing và GitOps hoàn chỉnh.

---

## GIAI ĐOẠN 5: INFRASTRUCTURE AS CODE (TERRAFORM + ANSIBLE)

- **Thời gian thực hiện:** 11/09/2026
- **Mục tiêu:** Tự động hóa 100% việc chuẩn bị hệ điều hành các node (Ansible) và quản lý tài nguyên logic cụm K8s bằng mã khai báo (Terraform).

### 1. Triển khai Ansible (Tầng Hệ điều hành & Node)
- **Cấu trúc:** Xây dựng `inventory.ini`, `ansible.cfg`, và Playbook `setup-k8s-node.yml`.
- **Cơ chế:** Node master `k8s-master-1` đóng vai trò Ansible Control Node, kết nối SSH đồng nhất tới cả 3 node.
- **Các tác vụ tự động hóa:**
  1. Tắt Swap vĩnh viễn trong `/etc/fstab`.
  2. Nạp kernel modules `overlay`, `br_netfilter`.
  3. Cấu hình sysctl chuyển tiếp mạng `net.ipv4.ip_forward = 1`.
  4. Cài đặt các gói phụ trợ và cấu hình đồng bộ thời gian NTP (`chrony`).
  5. Cài đặt Container Runtime `containerd` với cờ `SystemdCgroup = true`.
  6. Thêm repository chính thức `pkgs.k8s.io` và cài đặt bộ ba `kubelet`, `kubeadm`, `kubectl` v1.30 kèm lệnh `hold` phiên bản.
- **Sự cố & Xử lý:** Task kích hoạt dịch vụ `chrony` gặp lỗi khi chạy dry-run/service không tìm thấy. Khắc phục bằng cách chuẩn hóa sang module `service` đa năng với `failed_when: false`. Playbook chạy thành công `ok=12, changed=1, failed=0` trên toàn bộ 3 node.

### 2. Triển khai Terraform (Tầng Kubernetes & Workload)
- **Cấu trúc:** Xây dựng module Terraform gồm `versions.tf` (Kubernetes provider), `variables.tf`, `main.tf`, `outputs.tf`.
- **Tài nguyên quản lý bằng code HCL:**
  - `kubernetes_namespace`: Quản lý namespace `robot-shop` kèm metadata chuẩn.
  - `kubernetes_resource_quota`: Thiết lập mức trần an toàn bảo vệ máy tính (Tối đa 8Gi RAM, 6 Cores CPU, tối đa 30 Pods).
  - `kubernetes_limit_range`: Tự động gán cấu hình request/limit mặc định cho mọi container.
- **Sự cố & Kỹ năng thực chiến:** Khi apply gặp lỗi `namespaces "robot-shop" already exists` do namespace đã có sẵn trước đó. Đã xử lý bằng kỹ thuật **`terraform import kubernetes_namespace.robot_shop robot-shop`** để đưa tài nguyên thực tế vào quản lý State của Terraform.
- **Kiểm chứng:** Lệnh `kubectl describe resourcequota robot-shop-quota -n robot-shop` ghi nhận đầy đủ 12 Pods của Robot Shop đang nằm trong hạn mức 3536Mi / 8Gi RAM và 2400m / 6 Cores CPU.

### 3. Đánh giá hoàn thành Giai đoạn 5
- [x] Chạy Ansible playbook cấu hình được toàn bộ các node từ đầu.
- [x] Quản lý thành công hạ tầng K8s (Namespace, ResourceQuota, LimitRange) bằng Terraform.
- [x] Làm chủ kỹ thuật `terraform import` và quản lý trạng thái hạ tầng bằng code (IaC).

---

## GIAI ĐOẠN 6: DEVSECOPS (TRIVY + SONARQUBE + VAULT)
*(Đang chuẩn bị thực hiện)*
