# Package Lambda PDF generator code
data "archive_file" "lambda_pdf" {
  type        = "zip"
  source_dir  = "${path.module}/functions/pdf_generator"
  output_path = "${path.module}/builds/pdf_generator.zip"
}

# Lambda function: PDF generator
resource "aws_lambda_function" "pdf_generator" {
  filename         = data.archive_file.lambda_pdf.output_path
  function_name    = "${local.lambda_prefix}-pdf-generator"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_pdf.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = 300   # 5 minutes
  memory_size      = 1024  # 1 GB for PDF generation

  layers = [aws_lambda_layer_version.psycopg2.arn]

  environment {
    variables = {
      S3_BUCKET     = var.s3_bucket_name
      DB_SECRET_ARN = aws_secretsmanager_secret.db_credentials.arn
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
      Name = "${local.lambda_prefix}-pdf-generator"
      Type = "PDF"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda_pdf,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy.lambda_secrets
  ]
}
