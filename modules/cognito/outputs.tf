# modules/cognito/outputs.tf

# User Pool
output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = aws_cognito_user_pool.main.endpoint
}

output "user_pool_domain" {
  description = "Cognito User Pool domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "user_pool_domain_cloudfront" {
  description = "CloudFront distribution for Cognito domain"
  value       = aws_cognito_user_pool_domain.main.cloudfront_distribution_arn
}

# Web Client
output "web_client_id" {
  description = "Web application client ID"
  value       = aws_cognito_user_pool_client.web.id
}

output "web_client_secret" {
  description = "Web application client secret (if generated)"
  value       = aws_cognito_user_pool_client.web.client_secret
  sensitive   = true
}

# Mobile Client
output "mobile_client_id" {
  description = "Mobile application client ID"
  value       = var.create_mobile_client ? aws_cognito_user_pool_client.mobile[0].id : ""
}

# Identity Pool
output "identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = var.create_identity_pool ? aws_cognito_identity_pool.main[0].id : ""
}

output "authenticated_role_arn" {
  description = "IAM role ARN for authenticated users"
  value       = var.create_identity_pool ? aws_iam_role.authenticated[0].arn : ""
}

# Groups
output "patients_group_name" {
  description = "Patients user group name"
  value       = aws_cognito_user_group.patients.name
}

output "admins_group_name" {
  description = "Admins user group name"
  value       = aws_cognito_user_group.admins.name
}

# Hosted UI URLs
output "hosted_ui_url" {
  description = "Cognito Hosted UI URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

output "login_url" {
  description = "Direct login URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.web.id}&response_type=code&redirect_uri=${var.callback_urls[0]}"
}

output "logout_url" {
  description = "Direct logout URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/logout?client_id=${aws_cognito_user_pool_client.web.id}&logout_uri=${var.logout_urls[0]}"
}

# Data source for region
data "aws_region" "current" {}