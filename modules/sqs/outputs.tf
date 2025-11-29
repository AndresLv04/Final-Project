// SQS MODULE - OUTPUTS

//Main Queue
output "queue_id" {
  description = "ID de la cola principal"
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "ARN de la cola principal"
  value       = aws_sqs_queue.main.arn
}

output "queue_url" {
  description = "URL de la cola principal"
  value       = aws_sqs_queue.main.url
}

output "queue_name" {
  description = "Nombre de la cola principal"
  value       = aws_sqs_queue.main.name
}

// Dead Letter Queue
output "dlq_id" {
  description = "ID del DLQ"
  value       = aws_sqs_queue.dlq.id
}

output "dlq_arn" {
  description = "ARN del DLQ"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "URL del DLQ"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_name" {
  description = "Nombre del DLQ"
  value       = aws_sqs_queue.dlq.name
}

# Alarmas
output "alarm_topic_arn" {
  description = "ARN del SNS topic para alarmas"
  value       = var.enable_cloudwatch_alarms && var.alarm_email != "" ? aws_sns_topic.alarms[0].arn : null
}