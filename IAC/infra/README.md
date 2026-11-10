# Hạ tầng AWS cho Robot Shop (Terraform)

Dựng hạ tầng cho cụm Kubernetes tự quản (kubeadm) trên AWS Academy Learner Lab:
1 AZ, edge node làm NAT và bastion, 1 master, 2 worker cố định, NLB, ECR, S3 backup, Secrets Manager.

Terraform chỉ dựng hạ tầng. Cài containerd, kubeadm và dựng cụm do Ansible làm,
dùng file inventory mà Terraform sinh ra trong `envs/dev/generated/`.

## Cấu trúc

```
infra/
├── bootstrap/            # S3 bucket chứa Terraform state, chạy một lần
├── envs/dev/             # Môi trường dev: gọi các module
│   └── templates/        # Mẫu inventory Ansible và ssh config
└── modules/
    ├── network/          # VPC, 2 subnet, IGW, 2 route table, S3 gateway endpoint
    ├── security/         # Security group cho edge, NLB, node Kubernetes
    ├── edge/             # EC2 NAT + bastion, Elastic IP, route 0.0.0.0/0 cho private
    ├── k8s-nodes/        # Master và worker, IP private cố định
    ├── nlb/              # NLB 80/443 -> NodePort Traefik trên worker
    ├── ecr/              # 10 repository image, quét khi push, tag bất biến
    ├── s3-backup/        # Bucket backup cơ sở dữ liệu
    └── secrets/          # Mật khẩu ngẫu nhiên lưu trong Secrets Manager
```

## Địa chỉ cố định

| Máy | Subnet | IP private | Loại |
| --- | --- | --- | --- |
| edge | Public 10.0.1.0/24 | 10.0.1.10 | t3.small |
| k8s-master | Private 10.0.11.0/24 | 10.0.11.10 | t3.medium |
| k8s-worker-1 | Private 10.0.11.0/24 | 10.0.11.21 | t3.large |
| k8s-worker-2 | Private 10.0.11.0/24 | 10.0.11.22 | t3.large |

Khi dựng cụm bằng kubeadm, dùng pod CIDR `192.168.0.0/16` (Calico chế độ VXLAN) để không trùng dải VPC.
Ansible cài Traefik dạng NodePort với cổng `30080` (HTTP) và `30443` (HTTPS) để khớp NLB.

## Ràng buộc Learner Lab đã tính đến

- Region `us-east-1`. AZ mặc định `us-east-1a`.
- Không tạo IAM role: mọi EC2 dùng `LabInstanceProfile`, key pair dùng `vockey` có sẵn.
- Credential tạm thời: mỗi phiên lab, chép lại nội dung "AWS Details > AWS CLI" vào `~/.aws/credentials`.
- Secret xóa ngay khi destroy (`recovery_window_in_days = 0`), ECR và bucket backup cho phép xóa khi còn dữ liệu, để dựng lại nhiều lần không vướng trùng tên.

## Cách chạy

Yêu cầu: Terraform 1.10 trở lên, AWS CLI, file khóa `labsuser.pem` tải từ Learner Lab.

**1. Tạo bucket chứa state (chỉ làm một lần)**

```bash
cd infra/bootstrap
terraform init
terraform apply
# ghi lại output state_bucket
```

**2. Cấu hình môi trường dev**

```bash
cd ../envs/dev
cp backend.hcl.example backend.hcl            # điền tên bucket vừa tạo
cp terraform.tfvars.example terraform.tfvars  # điền IP public của bạn
chmod 400 ~/.ssh/labsuser.pem
```

**3. Dựng hạ tầng**

```bash
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

**4. Kiểm tra**

```bash
ssh -F generated/ssh_config edge               # vào bastion
ssh -F generated/ssh_config k8s-master         # vào master qua bastion
ssh -F generated/ssh_config k8s-master 'curl -sI https://github.com | head -1'   # NAT hoạt động
```

**5. Dọn khi nghỉ dài ngày**

```bash
terraform destroy
```

NLB, Elastic IP và ổ EBS vẫn tính tiền khi EC2 đã dừng, nên nghỉ dài thì destroy.
Không destroy thư mục `bootstrap`, vì state nằm trong đó.

## Chi phí ước tính khi chạy

| Thành phần | USD/giờ |
| --- | --- |
| 1 x t3.medium (master) | 0,042 |
| 2 x t3.large (worker) | 0,166 |
| 1 x t3.small (edge) | 0,021 |
| NLB | ~0,023 + LCU |
| 2 IPv4 public (edge, NLB) | ~0,010 |
| EBS gp3 ~120 GB | ~0,013 |
| **Tổng** | **~0,28** |

Giá on-demand us-east-1, chưa gồm dữ liệu truyền ra Internet và Secrets Manager (0,40 USD/secret/tháng).

## Lưu ý

- Mật khẩu do module `secrets` sinh ra nằm trong Terraform state. Bucket state đã bật mã hóa và chặn truy cập công khai; không chia sẻ state.
- Target group của NLB tắt giữ IP client (`preserve_client_ip = false`) để rule security group tham chiếu `sg-nlb` hoạt động ổn định. Traefik vì vậy thấy IP của NLB, không phải IP người dùng.
- Node đặt `http_put_response_hop_limit = 2` để pod (EBS CSI driver, External Secrets Operator) dùng được quyền của `LabInstanceProfile` qua IMDS. Trong môi trường thật nên dùng IRSA hoặc Pod Identity thay cho cách này.
- Nếu tài khoản Learner Lab không đọc được instance profile qua API, thay data source `aws_iam_instance_profile` bằng chuỗi `"LabInstanceProfile"` trong `envs/dev/main.tf`.
