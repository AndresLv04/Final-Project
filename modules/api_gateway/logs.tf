# IAM role for API Gateway to write CloudWatch logs
resource "aws_iam_role" "apigw_cloudwatch" {
  name = "${local.api_name}-apigw-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# Attach managed policy for API Gateway logging to CloudWatch
resource "aws_iam_role_policy_attachment" "apigw_cloudwatch" {
  role       = aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# API Gateway account configuration using CloudWatch logs role
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn
}

# CloudWatch log group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway" {
  count             = var.enable_access_logs ? 1 : 0
  name              = "/aws/apigateway/${local.api_name}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# CloudWatch alarm for high 4XX errors
resource "aws_cloudwatch_metric_alarm" "api_4xx" {
  count = var.alarm_sns_topic_arn != "" ? 1 : 0

  alarm_name          = "${local.api_name}-4xx-errors"
  alarm_description   = "API Gateway 4XX errors are too high"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  threshold          = 10

  metric_name = "4XXError"
  namespace   = "AWS/ApiGateway"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  alarm_actions = [var.alarm_sns_topic_arn]

  tags = local.common_tags
}

# CloudWatch alarm for high 5XX errors
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  count = var.alarm_sns_topic_arn != "" ? 1 : 0

  alarm_name          = "${local.api_name}-5xx-errors"
  alarm_description   = "API Gateway 5XX errors detected"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 1
  threshold          = 5

  metric_name = "5XXError"
  namespace   = "AWS/ApiGateway"
  period      = 300
  statistic   = "Sum"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  alarm_actions = [var.alarm_sns_topic_arn]

  tags = local.common_tags
}

# CloudWatch alarm for high API latency
resource "aws_cloudwatch_metric_alarm" "api_latency" {
  count = var.alarm_sns_topic_arn != "" ? 1 : 0

  alarm_name          = "${local.api_name}-high-latency"
  alarm_description   = "API Gateway latency is too high"
  comparison_operator = "GreaterThanThreshold"

  evaluation_periods = 2
  threshold          = 5000

  metric_name = "Latency"
  namespace   = "AWS/ApiGateway"
  period      = 300
  statistic   = "Average"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  alarm_actions = [var.alarm_sns_topic_arn]

  tags = local.common_tags
}

