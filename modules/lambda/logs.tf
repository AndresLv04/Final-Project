// CLOUDWATCH LOG GROUPS

resource "aws_cloudwatch_log_group" "lambda_ingest" {
  name              = "/aws/lambda/${local.lambda_prefix}-ingest"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_notify" {
  name              = "/aws/lambda/${local.lambda_prefix}-notify"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_pdf" {
  name              = "/aws/lambda/${local.lambda_prefix}-pdf-generator"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_hl7" {
  name              = "/aws/lambda/${local.lambda_prefix}-hl7-adapter"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_xml" {
  name              = "/aws/lambda/${local.lambda_prefix}-xml-adapter"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_csv" {
  name              = "/aws/lambda/${local.lambda_prefix}-csv-adapter"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}


// CLOUDWATCH ALARMS

resource "aws_cloudwatch_metric_alarm" "lambda_csv_errors" {
  alarm_name          = "${local.lambda_prefix}-csv-errors"
  alarm_description   = "Lambda hl7 errors are too high"
  comparison_operator = "GreaterThanThreshold"
  
  evaluation_periods = 1
  threshold          = 5  # 5 errores
  
  metric_name = "Errors"
  namespace   = "AWS/Lambda"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    FunctionName = aws_lambda_function.csv_adapter.function_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = local.common_tags
}
# Alarma: Errores en Lambda xml
resource "aws_cloudwatch_metric_alarm" "lambda_xml_errors" {
  alarm_name          = "${local.lambda_prefix}-xml-errors"
  alarm_description   = "Lambda hl7 errors are too high"
  comparison_operator = "GreaterThanThreshold"
  
  evaluation_periods = 1
  threshold          = 5  # 5 errores
  
  metric_name = "Errors"
  namespace   = "AWS/Lambda"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    FunctionName = aws_lambda_function.xml_adapter.function_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = local.common_tags
}

# Alarma: Errores en Lambda hl7
resource "aws_cloudwatch_metric_alarm" "lambda_h17_errors" {
  alarm_name          = "${local.lambda_prefix}-hl7-errors"
  alarm_description   = "Lambda hl7 errors are too high"
  comparison_operator = "GreaterThanThreshold"
  
  evaluation_periods = 1
  threshold          = 5  # 5 errores
  
  metric_name = "Errors"
  namespace   = "AWS/Lambda"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    FunctionName = aws_lambda_function.hl7_adapter.function_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = local.common_tags
}

# Alarma: Errores en Lambda Ingest
resource "aws_cloudwatch_metric_alarm" "lambda_ingest_errors" {
  alarm_name          = "${local.lambda_prefix}-ingest-errors"
  alarm_description   = "Lambda Ingest errors are too high"
  comparison_operator = "GreaterThanThreshold"
  
  evaluation_periods = 1
  threshold          = 5  # 5 errores
  
  metric_name = "Errors"
  namespace   = "AWS/Lambda"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    FunctionName = aws_lambda_function.ingest.function_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = local.common_tags
}

# Alarma: Duración alta en Lambda PDF
resource "aws_cloudwatch_metric_alarm" "lambda_pdf_duration" {
  alarm_name          = "${local.lambda_prefix}-pdf-high-duration"
  alarm_description   = "PDF generation is taking too long"
  comparison_operator = "GreaterThanThreshold"
  
  evaluation_periods = 2
  threshold          = 60000  # 60 segundos en milisegundos
  
  metric_name = "Duration"
  namespace   = "AWS/Lambda"
  period      = 300
  statistic   = "Average"

  dimensions = {
    FunctionName = aws_lambda_function.pdf_generator.function_name
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = local.common_tags
}

