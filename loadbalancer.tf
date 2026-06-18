// ----------------- Route53 A Records -----------------

resource "aws_route53_record" "retail_banking" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "retail-banking.myatsumon.info"
  type    = "A"

  alias {
    name                   = aws_lb.customer_profile_alb.dns_name
    zone_id                = aws_lb.customer_profile_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "account" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "account.myatsumon.info"
  type    = "A"

  alias {
    name                   = aws_lb.account_alb.dns_name
    zone_id                = aws_lb.account_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "statement" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "statement.myatsumon.info"
  type    = "A"

  alias {
    name                   = aws_lb.statement_alb.dns_name
    zone_id                = aws_lb.statement_alb.zone_id
    evaluate_target_health = true
  }
}


// ----------------- customer-profile load balancer -----------------
resource "aws_lb_target_group" "customer_profile_tg" {
  region   = local.vpc_region["vpc-customer-profile"]
  name     = "customer-profile-tg"
  port     = 9091
  protocol = "HTTP"
  vpc_id   = module.vpc["vpc-customer-profile"].vpc_id

  health_check {
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
  }

}

resource "aws_lb" "customer_profile_alb" {
  region             = local.vpc_region["vpc-customer-profile"]
  name               = "customer-profile-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.ec2_customer_profile.security_group_id]
  subnets            = module.vpc["vpc-customer-profile"].subnet_ids

  tags = {
    Name = "customer-profile-alb"
  }
}

resource "aws_lb_listener" "https_customer_profile" {
  region            = local.vpc_region["vpc-customer-profile"]
  load_balancer_arn = aws_lb.customer_profile_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.this[local.vpc_region["vpc-customer-profile"]].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.customer_profile_tg.arn
  }
}

// ----------------- account load balancer -----------------
resource "aws_lb_target_group" "account_tg" {
  region   = local.vpc_region["vpc-account"]
  name     = "account-tg"
  port     = 9092
  protocol = "HTTP"
  vpc_id   = module.vpc["vpc-account"].vpc_id

  health_check {
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
  }

}

resource "aws_lb" "account_alb" {
  region             = local.vpc_region["vpc-account"]
  name               = "account-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [module.ec2_account.security_group_id]
  subnets            = module.vpc["vpc-account"].subnet_ids
  tags = {
    Name = "account-alb"
  }
}

resource "aws_lb_listener" "https_account" {
  region            = local.vpc_region["vpc-account"]
  load_balancer_arn = aws_lb.account_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.this[local.vpc_region["vpc-account"]].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.account_tg.arn
  }
}

// ----------------- statement load balancer -----------------
resource "aws_lb_target_group" "statement_tg" {
  region   = local.vpc_region["vpc-statement"]
  name     = "statement-tg"
  port     = 9093
  protocol = "HTTP"
  vpc_id   = module.vpc["vpc-statement"].vpc_id

  health_check {
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
  }

}

resource "aws_lb" "statement_alb" {
  region             = local.vpc_region["vpc-statement"]
  name               = "statement-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [module.ec2_statement.security_group_id]
  subnets            = module.vpc["vpc-statement"].subnet_ids
  tags = {
    Name = "statement-alb"
  }
}

resource "aws_lb_listener" "https_statement" {
  region            = local.vpc_region["vpc-statement"]
  load_balancer_arn = aws_lb.statement_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.this[local.vpc_region["vpc-statement"]].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.statement_tg.arn
  }
}
