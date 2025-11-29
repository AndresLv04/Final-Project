# ============================================
# API GATEWAY MODULE - OUTPUTS
# ============================================

output "api_id" {
  description = "ID del REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "ARN del REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_endpoint" {
  description = "URL base del API"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_key_id" {
  description = "ID del API Key"
  value       = aws_api_gateway_api_key.lab_external.id
}

output "api_key_value" {
  description = "Valor del API Key"
  value       = aws_api_gateway_api_key.lab_external.value
  sensitive   = true
}

output "stage_name" {
  description = "Nombre del stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "usage_plan_id" {
  description = "ID del usage plan"
  value       = aws_api_gateway_usage_plan.main.id
}

# URLs completas de endpoints
output "ingest_endpoint" {
  description = "URL completa del endpoint de ingesta"
  value       = "${aws_api_gateway_stage.main.invoke_url}/api/v1/ingest"
}

output "health_endpoint" {
  description = "URL completa del health check"
  value       = "${aws_api_gateway_stage.main.invoke_url}/api/v1/health"
}

output "pdf_endpoint" {
  description = "URL completa del endpoint PDF"
  value       = "${aws_api_gateway_stage.main.invoke_url}/api/v1/pdf"
}