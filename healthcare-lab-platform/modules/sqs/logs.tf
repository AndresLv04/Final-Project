
// CLOUDWATCH ALARMS

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.queue_name}-dlq-messages"
  alarm_description   = "Alert when messages appear in DLQ"
  comparison_operator = "GreaterThanThreshold"
  
  # Configuración del threshold
  evaluation_periods  = 1
  threshold           = 0  # Cualquier mensaje en DLQ es alerta
  treat_missing_data  = "notBreaching"

  # Métrica
  metric_name = "ApproximateNumberOfMessagesVisible"
  namespace   = "AWS/SQS"
  period      = 300  # 5 minutos
  statistic   = "Average"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  # Acciones (SNS topic para enviar emails)
  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# Alarma: Cola muy llena (workers no están procesando rápido)
resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.queue_name}-high-depth"
  alarm_description   = "Alert when queue has too many messages"
  comparison_operator = "GreaterThanThreshold"
  
  evaluation_periods = 2  # 2 periodos consecutivos
  threshold          = 100  # 100 mensajes
  treat_missing_data = "notBreaching"

  metric_name = "ApproximateNumberOfMessagesVisible"
  namespace   = "AWS/SQS"
  period      = 300
  statistic   = "Average"

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}

# Alarma: Mensajes muy viejos (workers no están procesando)
resource "aws_cloudwatch_metric_alarm" "message_age" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${local.queue_name}-old-messages"
  alarm_description   = "Alert when messages are too old"
  comparison_operator = "GreaterThanThreshold"
  
  evaluation_periods = 1
  threshold          = 600  # 10 minutos
  treat_missing_data = "notBreaching"

  metric_name = "ApproximateAgeOfOldestMessage"
  namespace   = "AWS/SQS"
  period      = 300
  statistic   = "Maximum"

  dimensions = {
    QueueName = aws_sqs_queue.main.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = local.common_tags
}


// SNS TOPIC PARA ALARMAS
resource "aws_sns_topic" "alarms" {
  count = var.enable_cloudwatch_alarms && var.alarm_email != "" ? 1 : 0

  name = "${local.queue_name}-alarms"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count = var.enable_cloudwatch_alarms && var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}