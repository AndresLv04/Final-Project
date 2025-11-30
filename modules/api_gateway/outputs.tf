# REST API ID
output "api_id" {
  description = "ID del REST API"
  value       = aws_api_gateway_rest_api.main.id
}

# REST API ARN
output "api_arn" {
  description = "ARN del REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

# Base URL of the API stage
output "api_endpoint" {
  description = "URL base del API"
  value       = aws_api_gateway_stage.main.invoke_url
}

# API key ID
output "api_key_id" {
  description = "ID del API Key"
  value       = aws_api_gateway_api_key.lab_external.id
}

# API key value (sensitive)
output "api_key_value" {
  description = "Valor del API Key"
  value       = aws_api_gateway_api_key.lab_external.value
  sensitive   = true
}

# Stage name
output "stage_name" {
  description = "Nombre del stage"
  value       = aws_api_gateway_stage.main.stage_name
}

# Usage plan ID
output "usage_plan_id" {
  description = "ID del usage plan"
  value       = aws_api_gateway_usage_plan.main.id
}

# Full URL for ingest endpoint
output "ingest_endpoint" {
  description = "URL completa del endpoint de ingesta"
  value       = "${aws_api_gateway_stage.main.invoke_url}/api/v1/ingest"
}

# Full URL for health endpoint
output "health_endpoint" {
  description = "URL completa del health check"
  value       = "${aws_api_gateway_stage.main.invoke_url}/api/v1/health"
}

# Full URL for PDF endpoint
output "pdf_endpoint" {
  description = "URL completa del endpoint PDF"
  value       = "${aws_api_gateway_stage.main.invoke_url}/api/v1/pdf"
}
