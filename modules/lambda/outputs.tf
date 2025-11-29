# ============================================
# LAMBDA MODULE - OUTPUTS
# ============================================

# Lambda Ingest
output "ingest_function_name" {
  description = "Nombre de Lambda Ingest"
  value       = aws_lambda_function.ingest.function_name
}

output "ingest_function_arn" {
  description = "ARN de Lambda Ingest"
  value       = aws_lambda_function.ingest.arn
}

output "ingest_invoke_arn" {
  description = "ARN de invocación para API Gateway"
  value       = aws_lambda_function.ingest.invoke_arn
}

# Lambda Notify
output "notify_function_name" {
  description = "Nombre de Lambda Notify"
  value       = aws_lambda_function.notify.function_name
}

output "notify_function_arn" {
  description = "ARN de Lambda Notify"
  value       = aws_lambda_function.notify.arn
}

# Lambda PDF
output "pdf_function_name" {
  description = "Nombre de Lambda PDF"
  value       = aws_lambda_function.pdf_generator.function_name
}

output "pdf_function_arn" {
  description = "ARN de Lambda PDF"
  value       = aws_lambda_function.pdf_generator.arn
}

output "pdf_invoke_arn" {
  description = "ARN de invocación para API Gateway"
  value       = aws_lambda_function.pdf_generator.invoke_arn
}

# IAM Role
output "lambda_execution_role_arn" {
  description = "ARN del rol de ejecución de Lambda"
  value       = aws_iam_role.lambda_execution.arn
}