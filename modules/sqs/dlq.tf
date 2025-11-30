# Locals
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  queue_name = "${var.project_name}-${var.environment}-lab-results-queue"
  dlq_name   = "${var.project_name}-${var.environment}-lab-results-dlq"
}

resource "aws_sqs_queue" "dlq" {
  name = local.dlq_name

  # Configuración
  message_retention_seconds = var.dlq_message_retention_seconds

  # Encriptación
  sqs_managed_sse_enabled = var.enable_encryption && var.kms_key_id == null
  kms_master_key_id       = var.kms_key_id

  # Data de encriptación
  kms_data_key_reuse_period_seconds = 300 # 5 minutos

  tags = merge(
    local.common_tags,
    {
      Name    = local.dlq_name
      Type    = "DeadLetterQueue"
      Purpose = "Failed lab results processing"
    }
  )
}