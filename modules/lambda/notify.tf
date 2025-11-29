# 5. LAMBDA FUNCTION: NOTIFY
# ============================================

data "archive_file" "lambda_notify" {
  type        = "zip"
  source_dir  = "${path.module}/functions/notify"
  output_path = "${path.module}/builds/notify.zip"
}

resource "aws_lambda_function" "notify" {
  filename         = data.archive_file.lambda_notify.output_path
  function_name    = "${local.lambda_prefix}-notify"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_notify.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  # Layer para psycopg2
  layers = [aws_lambda_layer_version.psycopg2.arn]

  environment {
    variables = {
      DB_SECRET_ARN = aws_secretsmanager_secret.db_credentials.arn
      SENDER_EMAIL  = var.ses_email_identity
      PORTAL_URL    = var.portal_url
      SES_TEMPLATE_NAME = "${var.project_name}-${var.environment}-result-ready"
      SES_CONFIG_SET    = var.ses_configuration_set
      ENVIRONMENT   = var.environment
      LOG_LEVEL     = "INFO"
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.lambda_prefix}-notify"
      Type = "Notification"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda_notify,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy.lambda_secrets
  ]
}
