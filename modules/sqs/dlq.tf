# Dead-letter queue for failed lab result processing
resource "aws_sqs_queue" "dlq" {
  name = local.dlq_name

  # DLQ message retention period
  message_retention_seconds = var.dlq_message_retention_seconds

  # Encryption settings
  sqs_managed_sse_enabled           = var.enable_encryption && var.kms_key_id == null
  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = 300 # 5 minutes

  tags = merge(
    local.common_tags,
    {
      Name    = local.dlq_name
      Type    = "DeadLetterQueue"
      Purpose = "Failed lab results processing"
    }
  )
}
