# Main SQS queue outputs
output "queue_id" {
  description = "ID of the main SQS queue"
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "ARN of the main SQS queue"
  value       = aws_sqs_queue.main.arn
}

output "queue_url" {
  description = "URL of the main SQS queue"
  value       = aws_sqs_queue.main.url
}

output "queue_name" {
  description = "Name of the main SQS queue"
  value       = aws_sqs_queue.main.name
}

# Dead-letter queue outputs
output "dlq_id" {
  description = "ID of the dead-letter queue"
  value       = aws_sqs_queue.dlq.id
}

output "dlq_arn" {
  description = "ARN of the dead-letter queue"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "URL of the dead-letter queue"
  value       = aws_sqs_queue.dlq.url
}

output "dlq_name" {
  description = "Name of the dead-letter queue"
  value       = aws_sqs_queue.dlq.name
}

# SNS topic for alarms
output "alarm_topic_arn" {
  description = "ARN of the SNS topic used for CloudWatch alarms"
  value       = var.enable_cloudwatch_alarms && var.alarm_email != "" ? aws_sns_topic.alarms[0].arn : null
}
