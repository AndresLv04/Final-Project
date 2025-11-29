# ===================================
# CloudWatch Logs & Alarms for Portal
# ===================================

# Log group for ECS portal
resource "aws_cloudwatch_log_group" "portal" {
  name              = "/ecs/${var.project_name}-${var.environment}/portal"
  retention_in_days = 7

  tags = var.common_tags
}

# High CPU alarm
resource "aws_cloudwatch_metric_alarm" "portal_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-portal-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Portal CPU utilization is too high"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.portal.name
  }

  tags = var.common_tags
}

# High memory alarm
resource "aws_cloudwatch_metric_alarm" "portal_memory_high" {
  alarm_name          = "${var.project_name}-${var.environment}-portal-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Portal memory utilization is too high"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.portal.name
  }

  tags = var.common_tags
}

# No running tasks alarm
resource "aws_cloudwatch_metric_alarm" "portal_task_count_low" {
  alarm_name          = "${var.project_name}-${var.environment}-portal-no-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Portal has no running tasks"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.portal.name
  }

  tags = var.common_tags
}
