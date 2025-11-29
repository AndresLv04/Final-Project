# ============================================
# NOTIFICATIONS MODULE - MAIN
# ============================================

# Locals
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  topic_name = "${var.project_name}-${var.environment}-result-ready"
}

# ============================================
# 1. SNS TOPIC - Result Ready
# ============================================

resource "aws_sns_topic" "result_ready" {
  name         = local.topic_name
  display_name = "Lab Result Ready Notification"

  # Encriptación
  kms_master_key_id = var.enable_sns_encryption ? (
    var.kms_key_id != null ? var.kms_key_id : "alias/aws/sns"
  ) : null

  # Delivery policy
  delivery_policy = jsonencode({
    http = {
      defaultHealthyRetryPolicy = {
        minDelayTarget     = 20
        maxDelayTarget     = 20
        numRetries         = 3
        numMaxDelayRetries = 0
        numNoDelayRetries  = 0
        numMinDelayRetries = 0
        backoffFunction    = "linear"
      }
      disableSubscriptionOverrides = false
    }
  })

  tags = merge(
    local.common_tags,
    {
      Name = local.topic_name
    }
  )
}

# ============================================
# 2. SNS TOPIC POLICY
# ============================================

resource "aws_sns_topic_policy" "result_ready" {
  arn = aws_sns_topic.result_ready.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPublishFromServices"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.result_ready.arn
      }
    ]
  })
}

# ============================================
# 3. SNS SUBSCRIPTION - Lambda Notify
# ============================================

resource "aws_sns_topic_subscription" "lambda_notify" {
  topic_arn = aws_sns_topic.result_ready.arn
  protocol  = "lambda"
  endpoint  = var.lambda_notify_function_arn

  # Filter policy (opcional)
  filter_policy = jsonencode({
    event_type = ["result_completed"]
  })
}

# Permiso para que SNS invoque Lambda
resource "aws_lambda_permission" "sns_notify" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_notify_function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.result_ready.arn
}

# ============================================
# 4. SES EMAIL IDENTITY
# ============================================

# Verificar email identity
resource "aws_ses_email_identity" "sender" {
  email = var.ses_email_identity
}

# ============================================
# 5. SES CONFIGURATION SET
# ============================================

resource "aws_ses_configuration_set" "main" {
  name = "${var.project_name}-${var.environment}-emails"

  # Tracking settings
  reputation_metrics_enabled = true
  sending_enabled            = true

  delivery_options {
    tls_policy = "Require" # Forzar TLS
  }
}

# ============================================
# 6. SES EVENT DESTINATION (CloudWatch)
# ============================================

resource "aws_ses_event_destination" "cloudwatch" {
  count = var.enable_ses_event_tracking ? 1 : 0

  name                   = "cloudwatch-destination"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true

  matching_types = [
    "send",
    "reject",
    "bounce",
    "complaint",
    "delivery",
    "open",
    "click"
  ]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "ses:configuration-set"
    value_source   = "emailHeader"
  }
}

# ============================================
# 7. SNS TOPIC PARA SES BOUNCES/COMPLAINTS
# ============================================

resource "aws_sns_topic" "ses_bounces" {
  count = var.enable_ses_event_tracking ? 1 : 0

  name         = "${var.project_name}-${var.environment}-ses-bounces"
  display_name = "SES Bounces and Complaints"

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "ses_bounces_email" {
  count = var.enable_ses_event_tracking ? 1 : 0

  topic_arn = aws_sns_topic.ses_bounces[0].arn
  protocol  = "email"
  endpoint  = var.support_email
}

# ============================================
# 8. SES IDENTITY NOTIFICATION TOPIC
# ============================================

resource "aws_ses_identity_notification_topic" "bounce" {
  count = var.enable_ses_event_tracking ? 1 : 0

  topic_arn                = aws_sns_topic.ses_bounces[0].arn
  notification_type        = "Bounce"
  identity                 = aws_ses_email_identity.sender.email
  include_original_headers = true
}

resource "aws_ses_identity_notification_topic" "complaint" {
  count = var.enable_ses_event_tracking ? 1 : 0

  topic_arn                = aws_sns_topic.ses_bounces[0].arn
  notification_type        = "Complaint"
  identity                 = aws_ses_email_identity.sender.email
  include_original_headers = true
}

# ============================================
# 9. SES EMAIL TEMPLATE
# ============================================

resource "aws_ses_template" "result_ready" {
  name    = "${var.project_name}-${var.environment}-result-ready"
  subject = "Your {{test_type}} Results Are Ready"

  html = templatefile("${path.module}/email_templates/result_ready.html", {
    portal_url    = var.portal_url
    support_email = var.support_email
  })

  text = <<-EOT
Hello {{first_name}},

Your lab results are now available for viewing.

Test Type: {{test_type}}
Test Date: {{test_date}}
Lab: {{lab_name}}

To view your results, please visit: ${var.portal_url}/results/{{result_id}}

If you have any questions, please contact your healthcare provider or email ${var.support_email}.

Best regards,
Healthcare Lab Platform
  EOT
}

