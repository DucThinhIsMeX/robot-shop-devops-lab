# 🤖 Tự Động Hóa Cấu Hình Kubernetes Node Bằng Ansible

Thư mục này chứa toàn bộ mã nguồn Ansible Playbook để tự động hóa 100% các bước chuẩn bị hệ điều hành Ubuntu cho một node Kubernetes từ đầu.

---

## 📂 Cấu Trúc Thư Mục

```
iac/ansible/
├── ansible.cfg          # Cấu hình tối ưu kết nối SSH và phân quyền sudo
├── inventory.ini        # Danh bạ IP các node (Master và Workers)
├── setup-k8s-node.yml   # Playbook thực thi A-Z
└── README.md            # Hướng dẫn chi tiết
```

---

## 🚀 Hướng Dẫn Thực Thi

### Bước 1: Cài đặt Ansible trên node Master (Control Node)
SSH vào `k8s-master-1` (`192.168.180.101`):
```bash
sudo apt update
sudo apt install -y ansible
```

### Bước 2: Thiết lập SSH Key không cần mật khẩu (từ Master sang các Worker)
Để Ansible tự động SSH vào cấu hình các máy khác:
```bash
# Tạo SSH key nếu chưa có
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519

# Copy key sang các node
ssh-copy-id devops@192.168.180.101
ssh-copy-id devops@192.168.180.102
ssh-copy-id devops@192.168.180.103
```

### Bước 3: Kiểm tra kết nối với Ansible Ping
```bash
ansible -i inventory.ini k8s_cluster -m ping
```
*(Nếu tất cả các node đều trả về màu xanh `"ping": "pong"` là kết nối thành công 100%)*.

### Bước 4: Chạy Playbook cấu hình
```bash
# Chạy chế độ xem trước (Dry-run / Check mode không làm thay đổi hệ thống)
ansible-playbook -i inventory.ini setup-k8s-node.yml --check

# Chạy thực tế
ansible-playbook -i inventory.ini setup-k8s-node.yml
```
