resource "aws_lb" "ingress_nlb" {
  name               = "${var.project}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = local.common_tags

  depends_on = [module.vpc]
}

resource "aws_lb_target_group" "ingress_nginx" {
  name        = "${var.project}-ingress-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/healthz"
    port                = "80"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = local.common_tags

  depends_on = [module.vpc]
}

resource "aws_lb_listener" "ingress_80" {
  load_balancer_arn = aws_lb.ingress_nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress_nginx.arn
  }
}
