# ============================================
# 10. CLOUDWATCH LOG GROUP PARA SNS
# ============================================

resource "aws_cloudwatch_log_group" "sns_delivery" {
  name              = "/aws/sns/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = local.common_tags
}

# ============================================
# 11. CLOUDWATCH ALARMS
# ============================================

# Alarma: Bounces altos
resource "aws_cloudwatch_metric_alarm" "ses_bounces" {
  count = var.enable_ses_event_tracking ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-ses-high-bounces"
  alarm_description   = "SES bounce rate is too high"
  comparison_operator = "GreaterThanThreshold"
  
  evaluation_periods = 1
  threshold          = 5  # 5 bounces
  
  metric_name = "Reputation.BounceRate"
  namespace   = "AWS/SES"
  period      = 300
  statistic   = "Average"

  alarm_actions = [aws_sns_topic.ses_bounces[0].arn]

  tags = local.common_tags
}

# Alarma: Complaints altos
resource "aws_cloudwatch_metric_alarm" "ses_complaints" {
  count = var.enable_ses_event_tracking ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-ses-high-complaints"
  alarm_description   = "SES complaint rate is too high"
  comparison_operator = "GreaterThanThreshold"
  
  evaluation_periods = 1
  threshold          = 0.1  # 0.1% complaint rate
  
  metric_name = "Reputation.ComplaintRate"
  namespace   = "AWS/SES"
  period      = 300
  statistic   = "Average"

  alarm_actions = [aws_sns_topic.ses_bounces[0].arn]

  tags = local.common_tags
}

# Alarma: SNS failed notifications
resource "aws_cloudwatch_metric_alarm" "sns_failed" {
  alarm_name          = "${var.project_name}-${var.environment}-sns-failed-notifications"
  alarm_description   = "SNS notifications are failing"
  comparison_operator = "GreaterThanThreshold"
  
  evaluation_periods = 1
  threshold          = 5
  
  metric_name = "NumberOfNotificationsFailed"
  namespace   = "AWS/SNS"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    TopicName = aws_sns_topic.result_ready.name
  }

  alarm_actions = [aws_sns_topic.result_ready.arn]

  tags = local.common_tags
}