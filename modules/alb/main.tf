
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
  
  cognito_name = "${var.project_name}-${var.environment}"

  portal_host = var.domain_name != "" ? var.domain_name : aws_lb.main.dns_name
  portal_scheme = var.certificate_arn != "" ? "https" : "http"
}

# ===================================
# Application Load Balancer
# ===================================

resource "aws_lb" "main" {
  name               = "${local.cognito_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = true
  enable_http2                     = true
  enable_waf_fail_open            = false

  idle_timeout = var.idle_timeout

  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = "alb-logs"
    enabled = var.enable_access_logs
  }

  tags = local.common_tags
}

# ===================================
# Target Group for ECS Portal
# ===================================

resource "aws_lb_target_group" "portal" {
  name        = "${var.project_name}-portaltg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Required for Fargate

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  # Deregistration delay
  deregistration_delay = 30

  # Stickiness (optional - for session persistence)
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 24 hours
    enabled         = var.enable_stickiness
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-portal-tg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ===================================
# HTTP Listener (Port 80)
# ===================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action depends on whether we have SSL
  dynamic "default_action" {
    for_each = var.certificate_arn != "" ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.certificate_arn == "" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.portal.arn
    }
  }

  tags = local.common_tags
}

# ===================================
# HTTPS Listener (Port 443) 
# ===================================

resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.portal.arn
  }

  tags = local.common_tags
}

# ===================================
# Listener Rules for Path-Based Routing
# ===================================

# Health check endpoint (no auth required)
resource "aws_lb_listener_rule" "health" {
  listener_arn = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.portal.arn
  }

  condition {
    path_pattern {
      values = ["/health", "/health/*"]
    }
  }

  tags = local.common_tags
}

# API endpoints (may want different routing in future)
resource "aws_lb_listener_rule" "api" {
  listener_arn = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.portal.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  tags = local.common_tags
}

# Static files (could serve from S3/CloudFront in future)
resource "aws_lb_listener_rule" "static" {
  listener_arn = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.portal.arn
  }

  condition {
    path_pattern {
      values = ["/static/*"]
    }
  }

  tags = local.common_tags
}


# ===================================
# WAF Association (Optional)
# ===================================

resource "aws_wafv2_web_acl_association" "alb" {
  count = var.waf_web_acl_arn != "" ? 1 : 0

  resource_arn = aws_lb.main.arn
  web_acl_arn  = var.waf_web_acl_arn
}