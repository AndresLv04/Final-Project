# Cognito User Pool ID
output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

# Cognito User Pool ARN
output "user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

# Cognito User Pool endpoint
output "user_pool_endpoint" {
  description = "Cognito User Pool endpoint"
  value       = aws_cognito_user_pool.main.endpoint
}

# Cognito Hosted UI domain
output "user_pool_domain" {
  description = "Cognito User Pool domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

# CloudFront distribution for Cognito domain
output "user_pool_domain_cloudfront" {
  description = "CloudFront distribution for Cognito domain"
  value       = aws_cognito_user_pool_domain.main.cloudfront_distribution_arn
}

# Web client ID
output "web_client_id" {
  description = "Web application client ID"
  value       = aws_cognito_user_pool_client.web.id
}

# Web client secret (sensitive)
output "web_client_secret" {
  description = "Web application client secret (if generated)"
  value       = aws_cognito_user_pool_client.web.client_secret
  sensitive   = true
}

# Mobile client ID (optional)
output "mobile_client_id" {
  description = "Mobile application client ID"
  value       = var.create_mobile_client ? aws_cognito_user_pool_client.mobile[0].id : ""
}

# Identity Pool ID (optional)
output "identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = var.create_identity_pool ? aws_cognito_identity_pool.main[0].id : ""
}

# IAM role ARN for authenticated Identity Pool users
output "authenticated_role_arn" {
  description = "IAM role ARN for authenticated users"
  value       = var.create_identity_pool ? aws_iam_role.authenticated[0].arn : ""
}

# Patients group name
output "patients_group_name" {
  description = "Patients user group name"
  value       = aws_cognito_user_group.patients.name
}

# Admins group name
output "admins_group_name" {
  description = "Admins user group name"
  value       = aws_cognito_user_group.admins.name
}

# Cognito Hosted UI base URL
output "hosted_ui_url" {
  description = "Cognito Hosted UI URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

# Direct login URL for Hosted UI
output "login_url" {
  description = "Direct login URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.web.id}&response_type=code&redirect_uri=${var.callback_urls[0]}"
}

# Direct logout URL for Hosted UI
output "logout_url" {
  description = "Direct logout URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com/logout?client_id=${aws_cognito_user_pool_client.web.id}&logout_uri=${var.logout_urls[0]}"
}
