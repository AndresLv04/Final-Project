resource "aws_sqs_queue" "main" {
  name = local.queue_name

  # Configuración de mensajes
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size          = var.max_message_size
  delay_seconds             = var.delay_seconds
  receive_wait_time_seconds = var.receive_wait_time_seconds  # Long polling

  # Encriptación
  sqs_managed_sse_enabled           = var.enable_encryption && var.kms_key_id == null
  kms_master_key_id                 = var.kms_key_id
  kms_data_key_reuse_period_seconds = 300

  # Dead Letter Queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  # Política de reintento
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.dlq.arn]
  })

  tags = merge(
    local.common_tags,
    {
      Name    = local.queue_name
      Type    = "MainQueue"
      Purpose = "Lab results processing queue"
    }
  )
}

// QUEUE POLICY (Permisos)
resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSendMessage"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "sns.amazonaws.com"
          ]
        }
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.main.arn
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "sqs:*"
        Resource = aws_sqs_queue.main.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}