# Project name
variable "project_name" {
  description = "Nombre del proyecto / Project name"
  type        = string
}

# Environment (dev, staging, prod)
variable "environment" {
  description = "Ambiente (dev, staging, prod) / Environment (dev, staging, prod)"
  type        = string
}

# Common tags map
variable "common_tags" {
  description = "Mapa de tags comunes / Common tags map"
  type        = map(string)
}

# Suffix for Cognito Hosted UI domain
variable "domain_suffix" {
  description = "Sufijo del dominio de Cognito / Cognito domain suffix"
  type        = string
  default     = "auth"
}

# Enable MFA in the user pool
variable "enable_mfa" {
  description = "Habilitar MFA (OPTIONAL u OFF) / Enable MFA"
  type        = bool
  default     = false
}

# Enable deletion protection on the user pool
variable "deletion_protection" {
  description = "Habilitar protección de borrado del User Pool / Enable Cognito deletion protection"
  type        = bool
  default     = true
}

# Callback URLs for the web client
variable "callback_urls" {
  description = "Lista de URLs de callback para el cliente web / Web client callback URLs"
  type        = list(string)
}

# Logout URLs for the web client
variable "logout_urls" {
  description = "Lista de URLs de logout para el cliente web / Web client logout URLs"
  type        = list(string)
}

# Create additional mobile client
variable "create_mobile_client" {
  description = "Crear un User Pool Client adicional para mobile / Create mobile client"
  type        = bool
  default     = false
}

# Mobile client callback URLs
variable "mobile_callback_urls" {
  description = "Lista de URLs de callback para el cliente móvil / Mobile client callback URLs"
  type        = list(string)
  default     = []
}

# Mobile client logout URLs
variable "mobile_logout_urls" {
  description = "Lista de URLs de logout para el cliente móvil / Mobile client logout URLs"
  type        = list(string)
  default     = []
}

# Create Cognito Identity Pool
variable "create_identity_pool" {
  description = "Crear Identity Pool para acceso directo a AWS / Create Cognito Identity Pool"
  type        = bool
  default     = false
}

# S3 reports bucket ARN for Identity Pool policy
variable "s3_reports_bucket_arn" {
  description = "ARN del bucket S3 donde se almacenan los reportes PDF / S3 reports bucket ARN"
  type        = string
  default     = ""
}

# Pre sign-up trigger Lambda ARN (optional)
variable "pre_signup_lambda_arn" {
  description = "ARN de la función Lambda para el trigger Pre Sign-up / Pre sign-up Lambda ARN"
  type        = string
  default     = ""
}

# Post confirmation trigger Lambda ARN (optional)
variable "post_confirmation_lambda_arn" {
  description = "ARN de la función Lambda para el trigger Post Confirmation / Post confirmation Lambda ARN"
  type        = string
  default     = ""
}

