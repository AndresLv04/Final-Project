# CloudFront distribution ID
output "distribution_id" {
  description = "ID de la distribución CloudFront"
  value       = aws_cloudfront_distribution.portal.id
}

# Public CloudFront domain name
output "domain_name" {
  description = "Dominio público de CloudFront para el portal"
  value       = aws_cloudfront_distribution.portal.domain_name
}

# Base HTTPS URL for the portal via CloudFront
output "portal_url" {
  description = "URL base HTTPS del portal vía CloudFront"
  value       = "https://${aws_cloudfront_distribution.portal.domain_name}"
}

