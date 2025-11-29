# Empaquetar código HL7 adapter
data "archive_file" "lambda_hl7_adapter" {
  type        = "zip"
  source_dir  = "${path.module}/functions/hl7_adapter"
  output_path = "${path.module}/builds/hl7_adapter.zip"
}

resource "aws_lambda_function" "hl7_adapter" {
  filename         = data.archive_file.lambda_hl7_adapter.output_path
  function_name    = "${local.lambda_prefix}-hl7-adapter"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_hl7_adapter.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      INGEST_FUNCTION_NAME = aws_lambda_function.ingest.function_name
      LAB_ID               = "LAB002"
      LAB_NAME             = "LabCorp"
      LOG_LEVEL            = "INFO"
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  tags = merge(
    local.common_tags,
    {
      Name   = "${local.lambda_prefix}-hl7-adapter"
      Type   = "Adapter"
      Format = "HL7"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda_hl7,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.lambda_vpc
  ]
}

