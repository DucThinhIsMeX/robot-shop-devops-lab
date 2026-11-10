# Dựng cụm Kubernetes bằng Ansible và kubeadm

Playbook đọc inventory do Terraform sinh ra, rồi dựng cụm 1 master, 2 worker trên hạ tầng AWS đã có.
Một lệnh `ansible-playbook site.yml` đi từ máy trống tới cụm chạy được, kèm CNI, metrics-server và ingress.

## Thành phần được cài

| Thành phần | Phiên bản | Vai trò |
| --- | --- | --- |
| Kubernetes (kubeadm, kubelet, kubectl) | 1.36 | Hỗ trợ tới 28-6-2027 |
| containerd | 2.3.7 | Container runtime; Kubernetes từ 1.36 không còn hỗ trợ containerd 1.x |
| runc | 1.4.3 | Runtime cấp thấp cho containerd |
| CNI plugins | 1.9.1 | Plugin mạng cơ bản |
| Calico (Tigera operator) | v3.33.0 | CNI, chế độ VXLAN, pod CIDR 192.168.0.0/16 |
| Helm | v4.3.1 | Cài các chart trên master |
| metrics-server | chart 3.14.0 | Số liệu CPU, RAM cho HPA |
| Gateway API CRD | v1.6.3 | API định tuyến thế hệ mới |
| Traefik | chart 42.3.0 | Ingress controller, hỗ trợ cả Ingress lẫn Gateway API; NodePort 30080, 30443 khớp NLB |

Phiên bản khai báo ở `group_vars/all.yml`. Kiểm tra lại trước mỗi lần dựng mới.

Traefik thay cho ingress-nginx vì dự án ingress-nginx đã ngừng phát triển từ tháng 3-2026, không còn bản vá bảo mật.

## Cấu trúc

```
ansible/
├── ansible.cfg              # inventory trỏ tới ../infra/envs/dev/generated/inventory.ini
├── group_vars/all.yml       # phiên bản, CIDR, NodePort
├── site.yml                 # dựng cụm
├── reset.yml                # gỡ cụm để dựng lại, giữ nguyên hạ tầng
├── requirements.yml         # collection Ansible cần cài
└── roles/
    ├── common/              # swap, kernel module, sysctl, containerd, runc, CNI, kubeadm
    ├── control_plane/       # kubeadm init, kubeconfig, sinh lệnh join
    ├── worker/              # kubeadm join
    └── addons/              # Helm, Calico, duyệt CSR kubelet, metrics-server, Gateway API, Traefik
```

Thư mục `ansible/` đặt cạnh `infra/` trong cùng repo.

## Cách chạy

Yêu cầu trên máy điều khiển: Ansible 2.16 trở lên, file khóa `labsuser.pem`, đã chạy `terraform apply` để có `generated/inventory.ini`.

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible all -m ping                 # kiểm tra kết nối qua bastion
ansible-playbook site.yml           # khoảng 10-15 phút
```

## Dùng kubectl từ máy của bạn

Playbook lưu kubeconfig vào `generated/kubeconfig`, trỏ tới `127.0.0.1:6443`. Mở đường hầm SSH tới API server qua edge rồi dùng như bình thường:

```bash
ssh -F ../infra/envs/dev/generated/ssh_config -fN -L 6443:10.0.11.10:6443 edge
export KUBECONFIG=$PWD/generated/kubeconfig
kubectl get nodes -o wide
kubectl top nodes
```

Chứng chỉ của API server đã có `127.0.0.1` trong danh sách SAN, nên kết nối qua đường hầm không bị lỗi xác thực.

## Kiểm tra sau khi dựng

```bash
kubectl get nodes                          # 3 node Ready
kubectl get pods -A                        # calico, metrics-server, traefik Running
kubectl get svc -n traefik                 # NodePort 30080, 30443
curl -I http://$(cd ../infra/envs/dev && terraform output -raw nlb_dns_name | sed 's#http://##')
```

Lệnh `curl` cuối trả về `404` từ Traefik là đúng: NLB đã thông tới Traefik, chỉ chưa có ứng dụng nào được định tuyến.

## Ghi chú thiết kế

- **Chứng chỉ kubelet do CA của cụm ký** (`serverTLSBootstrap: true`), playbook tự duyệt CSR. Nhờ đó metrics-server xác thực được kubelet, không phải dùng cờ `--kubelet-insecure-tls`.
- **Lệnh join và token không in ra log** (`no_log: true`). Token sống 1 giờ.
- **Chạy lại an toàn**: các bước `kubeadm init`, `kubeadm join` có điều kiện `creates`, chạy lại playbook không phá cụm đang chạy.
- **Dựng lại từ đầu**: `ansible-playbook reset.yml` rồi `ansible-playbook site.yml`.
