# Main data bucket outputs
output "data_bucket_id" {
  description = "ID of the main data bucket"
  value       = aws_s3_bucket.data.id
}

output "data_bucket_arn" {
  description = "ARN of the main data bucket"
  value       = aws_s3_bucket.data.arn
}

output "data_bucket_domain_name" {
  description = "Domain name of the data bucket"
  value       = aws_s3_bucket.data.bucket_domain_name
}

output "data_bucket_regional_domain_name" {
  description = "Regional domain name of the data bucket"
  value       = aws_s3_bucket.data.bucket_regional_domain_name
}

# Logs bucket outputs
output "logs_bucket_id" {
  description = "ID of the logs bucket"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "ARN of the logs bucket"
  value       = aws_s3_bucket.logs.arn
}

# Useful outputs for other modules
output "data_bucket_name" {
  description = "Name of the data bucket (for Lambda, ECS, etc.)"
  value       = aws_s3_bucket.data.id
}

output "bucket_prefixes" {
  description = "Organizational prefixes used in the data bucket"
  value = {
    incoming  = "incoming/"
    processed = "processed/"
    reports   = "reports/"
  }
}
