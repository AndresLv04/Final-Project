# CloudWatch Alarms

# CloudWatch alarm for high ALB target response time
resource "aws_cloudwatch_metric_alarm" "target_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1.0" # 1 second
  alarm_description   = "ALB target response time is too high"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.portal.arn_suffix
  }

  tags = local.common_tags
}

# CloudWatch alarm for unhealthy ALB targets
resource "aws_cloudwatch_metric_alarm" "unhealthy_target_count" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "ALB has unhealthy targets"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.portal.arn_suffix
  }

  tags = local.common_tags
}

# CloudWatch alarm for high 5xx errors from ALB targets
resource "aws_cloudwatch_metric_alarm" "http_5xx_count" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "ALB is receiving too many 5xx errors from targets"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.portal.arn_suffix
  }

  tags = local.common_tags
}

# CloudWatch alarm for rejected connections on the ALB
resource "aws_cloudwatch_metric_alarm" "rejected_connection_count" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-rejected-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RejectedConnectionCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "ALB is rejecting connections"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = local.common_tags
}

# CloudWatch log group for ALB access logs
resource "aws_cloudwatch_log_group" "alb" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  name              = "/aws/alb/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = local.common_tags
}

# Route53 A record alias pointing domain to ALB
resource "aws_route53_record" "alb" {
  count = var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
