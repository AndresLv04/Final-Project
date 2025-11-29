# Bucket de datos principal
output "data_bucket_id" {
  description = "ID del bucket de datos principal"
  value       = aws_s3_bucket.data.id
}

output "data_bucket_arn" {
  description = "ARN del bucket de datos principal"
  value       = aws_s3_bucket.data.arn
}

output "data_bucket_domain_name" {
  description = "Domain name del bucket de datos"
  value       = aws_s3_bucket.data.bucket_domain_name
}

output "data_bucket_regional_domain_name" {
  description = "Regional domain name del bucket"
  value       = aws_s3_bucket.data.bucket_regional_domain_name
}

# Bucket de logs
output "logs_bucket_id" {
  description = "ID del bucket de logs"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "ARN del bucket de logs"
  value       = aws_s3_bucket.logs.arn
}

# Outputs útiles para otros módulos
output "data_bucket_name" {
  description = "Nombre del bucket de datos (para Lambda, ECS, etc.)"
  value       = aws_s3_bucket.data.id
}

# Prefijos para organización
output "bucket_prefixes" {
  description = "Prefijos organizacionales del bucket"
  value = {
    incoming  = "incoming/"
    processed = "processed/"
    reports   = "reports/"
  }
}