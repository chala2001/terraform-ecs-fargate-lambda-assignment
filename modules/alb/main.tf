# ---------- ALB security group ----------

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB: HTTP in from allowed_cidr, out to tasks in the VPC"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name_prefix}-alb-sg" }
}

# Inbound: HTTP 80 from users
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from users"
  cidr_ipv4         = var.allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# Outbound: only to the app port INSIDE the VPC (least privilege)
resource "aws_vpc_security_group_egress_rule" "to_tasks" {
  security_group_id = aws_security_group.alb.id
  description       = "To ECS tasks on the app port"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = var.app_port
  to_port           = var.app_port
}

# ---------- Load balancer ----------

# Internet-facing ALB in the PUBLIC subnets (the only public component)
resource "aws_lb" "this" {
  name                       = "${var.name_prefix}-alb"
  internal                   = false # false = reachable from the internet
  load_balancer_type         = "application"
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true # Security best practice: reject malformed headers

  tags = { Name = "${var.name_prefix}-alb" }
}

# Target group: where the ALB sends traffic (ECS registers task IPs here)
resource "aws_lb_target_group" "app" {
  name                 = "${var.name_prefix}-tg"
  port                 = var.app_port
  protocol             = "HTTP"
  target_type          = "ip" # Fargate tasks are registered by IP (awsvpc mode)
  vpc_id               = var.vpc_id
  deregistration_delay = 30   # Wait 30s (not the default 300s) before removing a task

  # The ALB only sends traffic to tasks that pass this check
  health_check {
    path                = var.health_check_path
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.name_prefix}-tg" }
}

# Listener: listen on port 80 and forward everything to the target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP" # HTTPS needs a domain + ACM certificate (future improvement)

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = { Name = "${var.name_prefix}-http-listener" }
}