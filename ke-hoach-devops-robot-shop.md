# KẾ HOẠCH DỰ ÁN DEVOPS A-Z: ROBOT SHOP TRÊN CỤM ON-PREMISE

> Dự án cá nhân - dựng một pipeline DevOps hoàn chỉnh cấp doanh nghiệp trên laptop, dùng `instana/robot-shop` làm ứng dụng thí nghiệm.

---

## 0. BỐI CẢNH & TÀI NGUYÊN

### Phần cứng
- Laptop: Intel i7-10850H (6 nhân / 12 luồng), 32GB RAM.
- Ảo hóa: VMware Workstation (dùng snapshot + linked clone).

### Sơ đồ hạ tầng (bản đồ IP)

| VM | IP | Vai trò |
|---|---|---|
| gitlab-server | 192.168.180.51 | Git + CI + Container Registry |
| k8s-master-1 | 192.168.180.101 | Control-plane (etcd + master) |
| k8s-master-2 | 192.168.180.102 | Worker |
| k8s-master-3 | 192.168.180.103 | Worker |
| rancher-server | 192.168.180.104 | Quản trị cụm (giao diện web) |
| loadbalancer-k8s | 192.168.180.105 | Ingress LB (HAProxy) |
| database-server | 192.168.180.106 | Tooling host: SonarQube + Vault + Trivy |

> **Ghi chú vai trò .106:** Robot Shop chạy database (Redis/MySQL/MongoDB) *bên trong* cụm qua Helm. Nên .106 được tái sử dụng làm "máy công cụ nặng" - đặt SonarQube, Vault, Trivy server ở đây để không giành RAM với cụm K8s. (Biến thể nâng cao: đưa database ra ngoài cụm, đặt lên .106 - xem Phụ lục B.)

### Nguyên tắc vàng về RAM
Không bao giờ bật tất cả VM cùng lúc. Mỗi giai đoạn chỉ bật nhóm VM cần thiết. Luôn đặt `resources.limits` cho mọi Pod. Snapshot trước mỗi bước rủi ro.

---

## LỘ TRÌNH TỔNG QUAN (9 giai đoạn)

```
GĐ0  Củng cố nền tảng cụm          → cụm khỏe, có storage + ingress
GĐ1  Triển khai Robot Shop thủ công → có app chạy làm mốc so sánh
GĐ2  Source control (GitLab)        → code + config repo tách biệt
GĐ3  CI pipeline                    → build-test-scan-push image tự động
GĐ4  GitOps CD (ArgoCD)             → triển khai tự động từ Git
GĐ5  Infrastructure as Code         → Terraform + Ansible tái lập hạ tầng
GĐ6  DevSecOps                      → Trivy + SonarQube + Vault
GĐ7  Observability                  → Prometheus + Grafana + Loki
GĐ8  Load balancer + kiểm thử tải   → HAProxy .105 + Locust
GĐ9  Hoàn thiện & portfolio         → tài liệu + sơ đồ + bài viết
```

---

## GIAI ĐOẠN 0 - CỦNG CỐ NỀN TẢNG CỤM

**Mục tiêu:** Đảm bảo cụm thật sự khỏe và đủ điều kiện chạy workload stateful trước khi xây lên trên.

**VM cần bật:** 3 node K8s (.101/.102/.103) + rancher (.104). *~12GB RAM.*

### Việc cần làm
1. Kiểm tra sức khỏe: `kubectl get nodes -o wide` (cả 3 `Ready`, đúng vai trò), `kubectl get pods -A` (kube-system + CoreDNS + CNI đều `Running`).
2. Cài **StorageClass** (bắt buộc cho database): local-path-provisioner của Rancher, đặt làm default.
3. Cài **Ingress controller** (Nginx hoặc Traefik) nếu chưa có sẵn.
4. Cấu hình **kubectl từ xa**: chép kubeconfig về máy điều khiển để khỏi SSH vào master mỗi lần.
5. Xác nhận **NTP/chrony** đồng bộ giờ trên mọi node (tránh hỏng chứng chỉ TLS).

### Tiêu chí hoàn thành
- [x] 3 node `Ready`
- [x] `kubectl get storageclass` có 1 class default (`local-path`)
- [x] Ingress controller `Running` (`ingress-nginx`)
- [x] Sẵn sàng cấp phát động cho PVC database

**Cạm bẫy thường gặp:** PVC kẹt `Pending` = thiếu StorageClass. Node `NotReady` = CNI chưa xong.

---

## GIAI ĐOẠN 1 - TRIỂN KHAI ROBOT SHOP THỦ CÔNG

**Mục tiêu:** Có ứng dụng chạy được làm "mốc" (baseline) - biết app trông thế nào khi khỏe mạnh, để về sau tự động hóa lại chính nó.

**VM cần bật:** như GĐ0.

### Việc cần làm
1. `git clone https://github.com/instana/robot-shop.git`
2. Tạo namespace: `kubectl create namespace robot-shop`
3. Cài qua Helm (bật `nodeport=true` vì chạy on-prem):
   ```
   cd robot-shop/K8s/helm
   helm install robot-shop --namespace robot-shop --set nodeport=true .
   ```
4. Theo dõi: `kubectl get pods -n robot-shop -w` đến khi tất cả `Running`.
5. Truy cập web qua NodePort của service `web`.

### Kiến trúc app (để hiểu mình đang triển khai gì)
```
web (Nginx+Angular) → các microservice:
  catalogue (Node)  → MongoDB
  user (Node)       → MongoDB + Redis
  cart (Node)       → Redis
  shipping (Java)   → MySQL
  ratings (PHP)     → MySQL
  payment (Python)  → RabbitMQ → dispatch (Go)
```

### Tiêu chí hoàn thành
- [x] Mọi pod `Running` (12/12 pod)
- [x] Mở web trên trình duyệt, đặt thử 1 đơn hàng thành công
- [x] Hiểu được service nào dùng DB/cache/broker nào

---

## GIAI ĐOẠN 2 - SOURCE CONTROL (GITLAB)

**Mục tiêu:** Đưa mã nguồn vào quản lý phiên bản, tách **code repo** và **config repo** - đúng chuẩn GitOps.

**VM cần bật:** gitlab (.51) + 3 node K8s. *Tắt rancher nếu chật. ~16GB.*

### Việc cần làm
1. Truy cập GitLab trên `.51`, tạo user + group dự án.
2. Tạo **2 repository**:
   - `robot-shop` (code + Dockerfile của từng service) - fork/mirror từ GitHub.
   - `robot-shop-deploy` (chỉ chứa Helm values / manifest K8s) - đây là repo ArgoCD sẽ theo dõi.
3. Cấu hình SSH key, push code lên.
4. Bật **Container Registry** tích hợp sẵn của GitLab (không cần dựng Harbor riêng).

### Vì sao tách 2 repo
Code thay đổi vì lý do phát triển; cấu hình triển khai thay đổi vì lý do vận hành. Tách ra giúp ArgoCD chỉ theo dõi repo cấu hình, và lịch sử triển khai sạch sẽ.

### Tiêu chí hoàn thành
- [x] 2 repo trên GitLab, push được code
- [x] Container Registry bật, đăng nhập được bằng `docker login` (hoặc sẵn sàng nhận image)

---

## GIAI ĐOẠN 3 - CI PIPELINE (BUILD - TEST - SCAN - PUSH)

**Mục tiêu:** Mỗi lần push code → tự động build image, chạy test, quét bảo mật cơ bản, đẩy image lên registry.

**VM cần bật:** gitlab (.51) + ≥1 worker để chạy Runner. *~14GB.*

### Việc cần làm
1. Cài **GitLab Runner** (dạng Docker executor, hoặc chạy trong cụm K8s).
2. Viết `.gitlab-ci.yml` cho một service trước (ví dụ `cart`), gồm các stage:
   ```
   stages: [build, test, scan, push]
   build → docker build image
   test  → chạy unit test
   scan  → Trivy quét lỗ hổng image (fail nếu có CRITICAL)
   push  → đẩy image tag theo commit SHA lên registry GitLab
   ```
3. Nhân rộng pipeline cho các service còn lại.
4. Dùng **image tag = commit SHA** (không dùng `latest`) để truy vết được.

### Tiêu chí hoàn thành
- [ ] Push code → pipeline chạy xanh
- [ ] Image xuất hiện trong Registry với tag đúng SHA
- [ ] Thử tạo lỗ hổng giả → pipeline `fail` ở stage scan

**Cạm bẫy:** "Docker-in-Docker" trên Runner cần cấu hình privileged hoặc dùng Kaniko/Buildah để build image an toàn hơn.

---

## GIAI ĐOẠN 4 - GITOPS CD (ARGOCD)

**Mục tiêu:** Ngừng `helm install` thủ công. ArgoCD tự đồng bộ cụm với repo `robot-shop-deploy` - Git là nguồn chân lý duy nhất.

**VM cần bật:** 3 node K8s + gitlab (.51). *~16GB.*

### Việc cần làm
1. Cài ArgoCD vào cụm (`kubectl apply` namespace argocd hoặc qua Helm).
2. Trỏ ArgoCD tới repo `robot-shop-deploy` trên GitLab.
3. Tạo một **Application** trong ArgoCD, bật `auto-sync` + `self-heal`.
4. Kiểm chứng vòng lặp GitOps: sửa số replica trong repo deploy → commit → ArgoCD tự áp dụng lên cụm mà không cần gõ lệnh.
5. (Nối tiếp GĐ3) Khi CI push image mới, cập nhật tag image trong repo deploy → ArgoCD tự triển khai bản mới.

### Tiêu chí hoàn thành
- [ ] ArgoCD hiển thị app `Synced` + `Healthy`
- [ ] Sửa Git → cụm tự đổi theo (không thao tác tay)
- [ ] Xóa thủ công 1 pod → ArgoCD/K8s tự dựng lại (self-heal)

> **Đây là kỹ năng giá trị nhất của cả dự án.** Ghi lại kỹ để đưa vào portfolio.

---

## GIAI ĐOẠN 5 - INFRASTRUCTURE AS CODE

**Mục tiêu:** Có thể xóa sạch và dựng lại toàn bộ chỉ bằng lệnh, không thao tác tay.

**VM cần bật:** tùy tác vụ.

### Việc cần làm
1. **Ansible** (tái lập cấu hình node): playbook tự động hóa các bước chuẩn bị node - tắt swap, cài container runtime, cấu hình sysctl, /etc/hosts, NTP. Mục tiêu: dựng lại một node mới chỉ bằng 1 lệnh.
2. **Terraform** (khai báo tài nguyên trong cụm): quản lý namespace, resource quota, và các Helm release bằng Terraform provider (`kubernetes` + `helm`). Mục tiêu: `terraform apply` dựng lại toàn bộ tầng ứng dụng.
3. Lưu toàn bộ code IaC vào một repo riêng trên GitLab.

### Tiêu chí hoàn thành
- [ ] Chạy Ansible playbook cấu hình được 1 node từ đầu
- [ ] `terraform apply` / `destroy` dựng lại / xóa sạch namespace robot-shop
- [ ] Không còn bước "bấm tay" nào trong việc dựng hạ tầng

---

## GIAI ĐOẠN 6 - DEVSECOPS (SHIFT-LEFT SECURITY)

**Mục tiêu:** Nhét bảo mật vào pipeline, không hard-code secret.

**VM cần bật:** database-server (.106) cho SonarQube + Vault. *Bật SonarQube chỉ khi cần quét - nó ngốn ~3GB.*

### Việc cần làm
1. **Trivy** (đã có ở GĐ3): mở rộng quét cả filesystem và cấu hình K8s, không chỉ image.
2. **SonarQube** (trên .106): thêm stage phân tích chất lượng mã vào pipeline; đặt "Quality Gate" - pipeline fail nếu điểm dưới ngưỡng.
3. **HashiCorp Vault** (trên .106): thay các secret hard-code (mật khẩu DB, token) bằng secret lấy động từ Vault. Học cơ chế inject secret vào pod.

### Tiêu chí hoàn thành
- [ ] Pipeline có stage SonarQube, fail khi code kém chất lượng
- [ ] Trivy chặn image có lỗ hổng nghiêm trọng
- [ ] Không còn mật khẩu nào nằm thô trong repo - tất cả qua Vault

---

## GIAI ĐOẠN 7 - OBSERVABILITY (GIÁM SÁT)

**Mục tiêu:** Nhìn thấy hệ thống - metrics, log, cảnh báo. Hoàn thiện vòng đời vận hành.

**VM cần bật:** 3 node K8s. *~13GB (bộ giám sát chạy nhẹ với Loki).*

### Việc cần làm
1. Cài **kube-prometheus-stack** (Prometheus + Grafana + Alertmanager) qua Helm.
2. Cài **Loki + Promtail** để gom log (nhẹ hơn ELK nhiều).
3. Tận dụng sẵn: service `cart` và `payment` của Robot Shop **có sẵn endpoint `/metrics` Prometheus** - cấu hình scrape chúng.
4. Dựng dashboard Grafana: CPU/RAM theo node, số request, độ trễ, trạng thái pod.
5. Tạo cảnh báo: pod chết, node RAM cao, service không phản hồi.

### Tiêu chí hoàn thành
- [ ] Grafana hiện dashboard cụm + Robot Shop
- [ ] Xem được log tập trung của mọi service qua Loki
- [ ] Tắt thử 1 service → nhận được cảnh báo

---

## GIAI ĐOẠN 8 - LOAD BALANCER + KIỂM THỬ TẢI

**Mục tiêu:** Một điểm truy cập duy nhất (như production) và kiểm chứng hệ chịu tải.

**VM cần bật:** loadbalancer (.105) + 3 node K8s.

### Việc cần làm
1. Cấu hình **HAProxy trên .105** trỏ tới Ingress controller / NodePort của service `web` trên cả 2 worker.
2. Truy cập Robot Shop qua đúng 1 địa chỉ `.105` thay vì IP từng node.
3. Dùng **load-gen (Locust)** có sẵn trong repo Robot Shop để tạo tải.
4. Quan sát trên Grafana lúc chịu tải: autoscaling (nếu bật HPA), độ trễ tăng, tài nguyên tiêu thụ.

### Tiêu chí hoàn thành
- [ ] Vào app qua địa chỉ LB `.105` duy nhất
- [ ] Chạy load test, xem được biểu đồ tải thời gian thực trên Grafana
- [ ] (Tùy chọn) Bật HPA → pod tự nhân bản khi tải cao

---

## GIAI ĐOẠN 9 - HOÀN THIỆN & PORTFOLIO

**Mục tiêu:** Biến dự án thành thứ trình bày được cho nhà tuyển dụng.

### Việc cần làm
1. Viết **README** tổng thể: mục tiêu, kiến trúc, công nghệ, cách chạy lại.
2. Vẽ **sơ đồ kiến trúc** toàn luồng: từ `git push` → CI → registry → ArgoCD → cụm → observability.
3. Viết **bài blog / write-up**: các quyết định thiết kế và lý do (vì sao 1 master + 2 worker, vì sao Loki thay ELK, vì sao tách 2 repo...).
4. Chụp ảnh màn hình các dashboard, pipeline xanh, ArgoCD synced.
5. Đẩy toàn bộ code (IaC, CI, config) lên GitHub công khai.

### Tiêu chí hoàn thành
- [ ] Repo GitHub có README + sơ đồ + tài liệu đầy đủ
- [ ] Có thể demo toàn luồng end-to-end trong 5 phút
- [ ] Giải thích được từng lựa chọn công nghệ

---

## TIMELINE GỢI Ý (làm bán thời gian)

| Tuần | Giai đoạn | Kết quả |
|---|---|---|
| 1 | GĐ0 + GĐ1 | Cụm khỏe + Robot Shop chạy |
| 2 | GĐ2 + GĐ3 | GitLab + CI pipeline xanh |
| 3 | GĐ4 | GitOps hoàn chỉnh (mốc quan trọng) |
| 4 | GĐ5 | IaC tái lập được hạ tầng |
| 5 | GĐ6 | Bảo mật tích hợp pipeline |
| 6 | GĐ7 | Giám sát + dashboard |
| 7 | GĐ8 + GĐ9 | LB, load test, tài liệu, portfolio |

---

## BẢNG NGÂN SÁCH RAM THEO GIAI ĐOẠN

| Giai đoạn | VM bật | RAM ước tính |
|---|---|---|
| GĐ0-1 | 3 K8s + rancher | ~12-13GB |
| GĐ2-4 | 3 K8s + gitlab | ~16GB |
| GĐ5 | tùy tác vụ | linh hoạt |
| GĐ6 | + database-server (SonarQube) | ~18-20GB (đỉnh) |
| GĐ7-8 | 3 K8s + LB | ~13-14GB |

> Đỉnh RAM ở GĐ6 khi bật SonarQube. Mẹo: quét SonarQube xong thì tắt VM .106 đi.

---

## PHỤ LỤC A - THỨ TỰ ƯU TIÊN NẾU THIẾU THỜI GIAN

Nếu chỉ làm được một phần, thứ tự "đắt giá" nhất cho portfolio:
1. GĐ4 (GitOps) - ấn tượng nhất
2. GĐ3 (CI) - nền tảng bắt buộc
3. GĐ7 (Observability) - nhà tuyển dụng rất thích
4. GĐ6 (DevSecOps) - điểm cộng lớn
5. GĐ5 (IaC) - thể hiện tư duy tự động hóa

## PHỤ LỤC B - BIẾN THỂ NÂNG CAO

- **Database ngoài cụm:** đưa MySQL/MongoDB ra VM .106, cấu hình Robot Shop trỏ ra ngoài - mô phỏng pattern production (DB tách khỏi cụm).
- **Thay RabbitMQ bằng Kafka/Redpanda:** bài tập kiến trúc hướng sự kiện, đúng công nghệ bạn quan tâm ban đầu.
- **Progressive delivery:** thêm Argo Rollouts để làm canary / blue-green deployment.
- **Service mesh:** cài Linkerd (nhẹ hơn Istio) để học mTLS và traffic management.

---

*Nguyên tắc xuyên suốt: hiểu vì sao mỗi công cụ có mặt, không chạy đua gom công cụ. Một luồng gọn gàng mà giải thích được từng lựa chọn thắng một mớ 30 công cụ không rõ tác dụng.*
