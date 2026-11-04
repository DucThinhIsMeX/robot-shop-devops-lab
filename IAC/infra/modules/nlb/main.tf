# NLB công khai: cổng 80/443 chuyển tới NodePort của ingress-nginx trên các worker.
resource "aws_lb" "this" {
  name               = "${var.name}-nlb"
  load_balancer_type = "network"
  internal           = false
  subnets            = [var.subnet_id]
  security_groups    = [var.security_group_id]

  tags = { Name = "${var.name}-nlb" }
}

resource "aws_lb_target_group" "ingress" {
  for_each = var.listeners

  name        = "${var.name}-tg-${each.key}"
  port        = each.value.node_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  # Tắt giữ IP client để nguồn gói tin là NLB, khớp rule security group tham chiếu sg-nlb.
  # Đánh đổi: ingress-nginx thấy IP của NLB thay vì IP người dùng.
  preserve_client_ip = "false"

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = { Name = "${var.name}-tg-${each.key}" }
}

resource "aws_lb_target_group_attachment" "workers" {
  for_each = {
    for pair in setproduct(keys(var.listeners), keys(var.worker_instance_ids)) :
    "${pair[0]}-${pair[1]}" => { listener = pair[0], worker = pair[1] }
  }

  target_group_arn = aws_lb_target_group.ingress[each.value.listener].arn
  target_id        = var.worker_instance_ids[each.value.worker]
  port             = var.listeners[each.value.listener].node_port
}

resource "aws_lb_listener" "this" {
  for_each = var.listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress[each.key].arn
  }
}
