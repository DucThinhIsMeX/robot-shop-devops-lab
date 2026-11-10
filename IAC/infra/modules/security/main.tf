# ---------- Edge: NAT + bastion ----------
resource "aws_security_group" "edge" {
  name        = "${var.name}-sg-edge"
  description = "Edge node: SSH bastion va NAT cho private subnet"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-sg-edge" }
}

resource "aws_vpc_security_group_ingress_rule" "edge_ssh" {
  for_each          = toset(var.admin_cidrs)
  security_group_id = aws_security_group.edge.id
  description       = "SSH tu may quan tri"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "edge_nat" {
  security_group_id = aws_security_group.edge.id
  description       = "Traffic tu private subnet di ra Internet qua NAT"
  cidr_ipv4         = var.private_subnet_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "edge_all" {
  security_group_id = aws_security_group.edge.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- NLB ----------
resource "aws_security_group" "nlb" {
  name        = "${var.name}-sg-nlb"
  description = "Network Load Balancer: HTTP va HTTPS tu Internet"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-sg-nlb" }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_web" {
  for_each          = toset(["80", "443", "30085"])
  security_group_id = aws_security_group.nlb.id
  description       = "Nguoi dung truy cap cong ${each.value}"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_nodes" {
  for_each                     = toset([for p in var.ingress_node_ports : tostring(p)])
  security_group_id            = aws_security_group.nlb.id
  description                  = "Chuyen tiep va health check toi NodePort ${each.value}"
  referenced_security_group_id = aws_security_group.k8s.id
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
}

# ---------- Kubernetes nodes ----------
resource "aws_security_group" "k8s" {
  name        = "${var.name}-sg-k8s"
  description = "Master va worker Kubernetes"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-sg-k8s" }
}

resource "aws_vpc_security_group_ingress_rule" "k8s_self" {
  security_group_id            = aws_security_group.k8s.id
  description                  = "Node noi chuyen voi nhau: etcd, kubelet, Calico VXLAN"
  referenced_security_group_id = aws_security_group.k8s.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_from_edge" {
  for_each                     = toset(["22", "6443"])
  security_group_id            = aws_security_group.k8s.id
  description                  = "Tu bastion, cong ${each.value}"
  referenced_security_group_id = aws_security_group.edge.id
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
}

resource "aws_vpc_security_group_ingress_rule" "k8s_from_rancher" {
  security_group_id            = aws_security_group.k8s.id
  description                  = "Tu Rancher server quan ly K8s API"
  referenced_security_group_id = aws_security_group.rancher.id
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
}

resource "aws_vpc_security_group_ingress_rule" "k8s_from_nlb" {
  for_each                     = toset([for p in var.ingress_node_ports : tostring(p)])
  security_group_id            = aws_security_group.k8s.id
  description                  = "NLB toi NodePort ingress ${each.value}"
  referenced_security_group_id = aws_security_group.nlb.id
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
}

resource "aws_vpc_security_group_egress_rule" "k8s_all" {
  security_group_id = aws_security_group.k8s.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- Rancher Server ----------
resource "aws_security_group" "rancher" {
  name        = "${var.name}-sg-rancher"
  description = "Rancher Dashboard: quan tri cum Kubernetes"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-sg-rancher" }
}

resource "aws_vpc_security_group_ingress_rule" "rancher_web" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.rancher.id
  description       = "Truy cap giao dien Rancher UI cong ${each.value}"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
}

resource "aws_vpc_security_group_ingress_rule" "rancher_ssh" {
  for_each          = toset(var.admin_cidrs)
  security_group_id = aws_security_group.rancher.id
  description       = "SSH tu may quan tri"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "rancher_all" {
  security_group_id = aws_security_group.rancher.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
