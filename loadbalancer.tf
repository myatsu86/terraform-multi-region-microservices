// ----------------- customer-profile load balancer -----------------
resource "aws_lb_target_group" "customer_profile_tg" {
  region   = local.vpc_region["vpc-public"]
  name     = "customer-profile-tg"
  port     = 9091
  protocol = "HTTP"
  vpc_id   = module.vpc["vpc-public"].vpc_id

  health_check {
  path                = "/"
  port                = "traffic-port"
  protocol            = "HTTP"
  healthy_threshold   = 2
  unhealthy_threshold = 2
  interval            = 15
  timeout             = 5
}

}

# resource "aws_lb_target_group_attachment" "customer_profile_attachment" {
#   for_each = module.ec2_customer_profile

#   target_group_arn = aws_lb_target_group.customer_profile_tg.arn
#   target_id        = each.value.instance_id
#   port             = 9091
# }

resource "aws_lb" "customer_profile_alb" {
  region             = local.vpc_region["vpc-public"]
  name               = "customer-profile-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [ module.ec2_customer_profile.security_group_id ]
  subnets            = module.vpc["vpc-public"].subnet_ids

  tags = {
    Name = "customer-profile-alb"
  }
}

resource "aws_lb_listener" "http_customer_profile" {
  region            = local.vpc_region["vpc-public"]
  load_balancer_arn = aws_lb.customer_profile_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.customer_profile_tg.arn
  }
}

// ----------------- account load balancer -----------------
resource "aws_lb_target_group" "account_tg" {
  region   = local.vpc_region["vpc-private-1"]
  name     = "account-tg"
  port     = 9092
  protocol = "HTTP"
  vpc_id   = module.vpc["vpc-private-1"].vpc_id

  health_check {
  path                = "/"
  port                = "traffic-port"
  protocol            = "HTTP"
  healthy_threshold   = 2
  unhealthy_threshold = 2
  interval            = 15
  timeout             = 5
}

}

# resource "aws_lb_target_group_attachment" "account_attachment" {
#   for_each = module.ec2_account
#   target_group_arn = aws_lb_target_group.account_tg.arn
#   target_id        = each.value.instance_id
#   port             = 9092
# }

resource "aws_lb" "account_alb" {
  region             = local.vpc_region["vpc-private-1"]
  name               = "account-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [module.ec2_account.security_group_id]
  subnets            = module.vpc["vpc-private-1"].subnet_ids
  tags = {
    Name = "account-alb"
  }
}

resource "aws_lb_listener" "http_account" {
  region            = local.vpc_region["vpc-private-1"]
  load_balancer_arn = aws_lb.account_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.account_tg.arn
  }
}

// ----------------- statement load balancer -----------------
resource "aws_lb_target_group" "statement_tg" {
  region   = local.vpc_region["vpc-private-2"]
  name     = "statement-tg"
  port     = 9093
  protocol = "HTTP"
  vpc_id   = module.vpc["vpc-private-2"].vpc_id

  health_check {
  path                = "/"
  port                = "traffic-port"
  protocol            = "HTTP"
  healthy_threshold   = 2
  unhealthy_threshold = 2
  interval            = 15
  timeout             = 5
}

}

# resource "aws_lb_target_group_attachment" "statement_attachment" {
#   for_each = module.ec2_statement
#   target_group_arn = aws_lb_target_group.statement_tg.arn
#   target_id        = each.value.instance_id
#   port             = 9093
# }

resource "aws_lb" "statement_alb" {
  region             = local.vpc_region["vpc-private-2"]
  name               = "statement-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [ module.ec2_statement.security_group_id ]
  subnets            = module.vpc["vpc-private-2"].subnet_ids
  tags = {
    Name = "statement-alb"
  }
}

resource "aws_lb_listener" "http_statement" {
  region            = local.vpc_region["vpc-private-2"]
  load_balancer_arn = aws_lb.statement_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.statement_tg.arn
  }
}