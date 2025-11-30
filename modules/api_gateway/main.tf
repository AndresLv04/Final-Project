# Local values for common tags and API name
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  api_name = "${var.project_name}-${var.environment}-api"
}

# REST API definition
resource "aws_api_gateway_rest_api" "main" {
  name        = local.api_name
  description = "Healthcare Lab Results API - ${var.environment}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.api_name
    }
  )
}

# /api base resource
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "api"
}

# /api/v1 resource
resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "v1"
}

# /api/v1/ingest resource
resource "aws_api_gateway_resource" "ingest" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "ingest"
}

# /api/v1/health resource
resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "health"
}

# /api/v1/pdf resource
resource "aws_api_gateway_resource" "pdf" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "pdf"
}

# POST /api/v1/ingest method
resource "aws_api_gateway_method" "ingest_post" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.ingest.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = var.enable_api_key_required

  request_validator_id = aws_api_gateway_request_validator.body.id
}

# Lambda proxy integration for POST /api/v1/ingest
resource "aws_api_gateway_integration" "ingest_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.ingest.id
  http_method = aws_api_gateway_method.ingest_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_ingest_invoke_arn
}

# Lambda permission for ingest endpoint
resource "aws_lambda_permission" "api_gateway_ingest" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_ingest_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# GET /api/v1/health method
resource "aws_api_gateway_method" "health_get" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.health.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = false
}

# MOCK integration for /api/v1/health
resource "aws_api_gateway_integration" "health_mock" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# 200 response for /api/v1/health
resource "aws_api_gateway_method_response" "health_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

# Integration response body for /api/v1/health
resource "aws_api_gateway_integration_response" "health" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method
  status_code = aws_api_gateway_method_response.health_200.status_code

  response_templates = {
    "application/json" = jsonencode({
      status      = "healthy"
      service     = "Healthcare Lab API"
      version     = "v1"
      environment = var.environment
    })
  }

  depends_on = [aws_api_gateway_integration.health_mock]
}

# POST /api/v1/pdf method
resource "aws_api_gateway_method" "pdf_post" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.pdf.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = var.enable_api_key_required
}

# Lambda proxy integration for POST /api/v1/pdf
resource "aws_api_gateway_integration" "pdf_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.pdf.id
  http_method = aws_api_gateway_method.pdf_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_pdf_invoke_arn
}

# Lambda permission for pdf endpoint
resource "aws_lambda_permission" "api_gateway_pdf" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_pdf_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# OPTIONS /api/v1/ingest method for CORS
resource "aws_api_gateway_method" "ingest_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.ingest.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# MOCK integration for OPTIONS /api/v1/ingest
resource "aws_api_gateway_integration" "ingest_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.ingest.id
  http_method = aws_api_gateway_method.ingest_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# CORS method response for OPTIONS /api/v1/ingest
resource "aws_api_gateway_method_response" "ingest_options_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.ingest.id
  http_method = aws_api_gateway_method.ingest_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# CORS integration response headers for OPTIONS /api/v1/ingest
resource "aws_api_gateway_integration_response" "ingest_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.ingest.id
  http_method = aws_api_gateway_method.ingest_options.http_method
  status_code = aws_api_gateway_method_response.ingest_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${join(",", var.cors_allow_origins)}'"
  }

  depends_on = [aws_api_gateway_integration.ingest_options]
}

# Request validator for JSON body
resource "aws_api_gateway_request_validator" "body" {
  name                        = "${local.api_name}-body-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = false
}

# API deployment with trigger for changes
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.ingest.id,
      aws_api_gateway_method.ingest_post.id,
      aws_api_gateway_integration.ingest_lambda.id,
      aws_api_gateway_resource.health.id,
      aws_api_gateway_method.health_get.id,
      aws_api_gateway_integration.health_mock.id,
      aws_api_gateway_resource.pdf.id,
      aws_api_gateway_method.pdf_post.id,
      aws_api_gateway_integration.pdf_lambda.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.ingest_lambda,
    aws_api_gateway_integration.health_mock,
    aws_api_gateway_integration.pdf_lambda,
    aws_api_gateway_integration_response.health,
  ]
}

# API Gateway stage for the environment
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  dynamic "access_log_settings" {
    for_each = var.enable_access_logs ? [1] : []

    content {
      destination_arn = aws_cloudwatch_log_group.api_gateway[0].arn
      format = jsonencode({
        requestId      = "$context.requestId"
        ip             = "$context.identity.sourceIp"
        caller         = "$context.identity.caller"
        user           = "$context.identity.user"
        requestTime    = "$context.requestTime"
        httpMethod     = "$context.httpMethod"
        resourcePath   = "$context.resourcePath"
        status         = "$context.status"
        protocol       = "$context.protocol"
        responseLength = "$context.responseLength"
      })
    }
  }

  xray_tracing_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.api_name}-${var.environment}"
    }
  )

  depends_on = [
    aws_api_gateway_account.this
  ]
}

# API key for external labs
resource "aws_api_gateway_api_key" "lab_external" {
  name    = "${local.api_name}-lab-external-key"
  enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.api_name}-lab-external-key"
      Type = "External-Lab"
    }
  )
}

# Usage plan for external labs
resource "aws_api_gateway_usage_plan" "main" {
  name        = "${local.api_name}-usage-plan"
  description = "Usage plan for external labs"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = var.api_quota_limit
    period = "DAY"
  }

  throttle_settings {
    rate_limit  = var.api_throttle_rate_limit
    burst_limit = var.api_throttle_burst_limit
  }

  tags = local.common_tags
}

# Link API key to usage plan
resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.lab_external.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}
