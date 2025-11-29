  // LAMBDA FUNCTION: INGEST

  # Empaquetar código
  data "archive_file" "lambda_ingest" {
    type        = "zip"
    source_dir  = "${path.module}/functions/ingest"
    output_path = "${path.module}/builds/ingest.zip"
  }

  resource "aws_lambda_function" "ingest" {
    filename         = data.archive_file.lambda_ingest.output_path
    function_name    = "${local.lambda_prefix}-ingest"
    role            = aws_iam_role.lambda_execution.arn
    handler         = "lambda_function.lambda_handler"
    source_code_hash = data.archive_file.lambda_ingest.output_base64sha256
    runtime         = var.lambda_runtime
    timeout         = var.lambda_timeout
    memory_size     = var.lambda_memory_size

    environment {
      variables = {
        S3_BUCKET       = var.s3_bucket_name
        SQS_QUEUE_URL   = var.sqs_queue_url
        ENVIRONMENT     = var.environment
        LOG_LEVEL       = "INFO"
      }
    }

    # VPC Configuration (para acceder a RDS)
    vpc_config {
      subnet_ids         = var.subnet_ids
      security_group_ids = [var.security_group_id]
    }

    tags = merge(
      local.common_tags,
      {
        Name = "${local.lambda_prefix}-ingest"
        Type = "Ingest"
      }
    )

    depends_on = [
      aws_cloudwatch_log_group.lambda_ingest,
      aws_iam_role_policy_attachment.lambda_logs,
      aws_iam_role_policy_attachment.lambda_vpc
    ]
  }



