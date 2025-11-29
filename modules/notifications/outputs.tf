# ============================================
# NOTIFICATIONS MODULE - OUTPUTS
# ============================================

# SNS
output "sns_topic_arn" {
  description = "ARN del SNS topic result-ready"
  value       = aws_sns_topic.result_ready.arn
}

output "sns_topic_name" {
  description = "Nombre del SNS topic"
  value       = aws_sns_topic.result_ready.name
}

# SES
output "ses_identity" {
  description = "Email identity verificado en SES"
  value       = aws_ses_email_identity.sender.email
}

output "ses_configuration_set" {
  description = "Nombre del configuration set de SES"
  value       = aws_ses_configuration_set.main.name
}

output "ses_template_name" {
  description = "Nombre del template de email"
  value       = aws_ses_template.result_ready.name
}

# Bounces/Complaints
output "ses_bounces_topic_arn" {
  description = "ARN del topic de bounces"
  value       = var.enable_ses_event_tracking ? aws_sns_topic.ses_bounces[0].arn : null
}