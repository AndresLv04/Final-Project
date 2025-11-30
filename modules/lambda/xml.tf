# Package XML adapter Lambda code
data "archive_file" "lambda_xml_adapter" {
  type        = "zip"
  source_dir  = "${path.module}/functions/xml_adapter"
  output_path = "${path.module}/builds/xml_adapter.zip"
}

# Lambda function: XML adapter
resource "aws_lambda_function" "xml_adapter" {
  filename         = data.archive_file.lambda_xml_adapter.output_path
  function_name    = "${local.lambda_prefix}-xml-adapter"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_xml_adapter.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      INGEST_FUNCTION_NAME = aws_lambda_function.ingest.function_name
      LAB_ID               = "HOSP001"
      LAB_NAME             = "Hospital Lab"
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
      Name   = "${local.lambda_prefix}-xml-adapter"
      Type   = "Adapter"
      Format = "XML"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda_xml,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.lambda_vpc
  ]
}

