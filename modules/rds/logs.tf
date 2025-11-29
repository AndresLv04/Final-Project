# ============================================
# 5. CLOUDWATCH ALARMS
# ============================================

// IAM ROLE PARA ENHANCED MONITORING
# ============================================
resource "aws_iam_role" "rds_monitoring" {
  name = "${local.db_identifier}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Alarma: CPU alta
resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.db_identifier}-high-cpu"
  alarm_description   = "RDS CPU utilization is too high"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  threshold          = 80 # 80% CPU

  metric_name = "CPUUtilization"
  namespace   = "AWS/RDS"
  period      = 300 # 5 minutos
  statistic   = "Average"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = local.common_tags
}

# Alarma: Storage bajo
resource "aws_cloudwatch_metric_alarm" "storage" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.db_identifier}-low-storage"
  alarm_description   = "RDS free storage is running low"
  comparison_operator = "LessThanThreshold"

  evaluation_periods = 1
  threshold          = 10 # 10% libre

  metric_name = "FreeStorageSpace"
  namespace   = "AWS/RDS"
  period      = 300
  statistic   = "Average"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = local.common_tags
}

# Alarma: Memoria baja
resource "aws_cloudwatch_metric_alarm" "memory" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.db_identifier}-low-memory"
  alarm_description   = "RDS freeable memory is too low"
  comparison_operator = "LessThanThreshold"

  evaluation_periods = 2
  threshold          = 256000000 # 256 MB en bytes

  metric_name = "FreeableMemory"
  namespace   = "AWS/RDS"
  period      = 300
  statistic   = "Average"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = local.common_tags
}

// Alarma: Conexiones altas
resource "aws_cloudwatch_metric_alarm" "connections" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.db_identifier}-high-connections"
  alarm_description   = "RDS database connections are too high"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  threshold          = 80

  metric_name = "DatabaseConnections"
  namespace   = "AWS/RDS"
  period      = 300
  statistic   = "Average"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = local.common_tags
}

# Alarma: Read Latency alta
resource "aws_cloudwatch_metric_alarm" "read_latency" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.db_identifier}-high-read-latency"
  alarm_description   = "RDS read latency is too high"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  threshold          = 0.1

  metric_name = "ReadLatency"
  namespace   = "AWS/RDS"
  period      = 300
  statistic   = "Average"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = local.common_tags
}

# Alarma: Write Latency alta
resource "aws_cloudwatch_metric_alarm" "write_latency" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.db_identifier}-high-write-latency"
  alarm_description   = "RDS write latency is too high"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  threshold          = 0.1

  metric_name = "WriteLatency"
  namespace   = "AWS/RDS"
  period      = 300
  statistic   = "Average"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  tags = local.common_tags
}