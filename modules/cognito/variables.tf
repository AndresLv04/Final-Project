// ============================================
// COGNITO MODULE - VARIABLES
// ============================================

/*
  Nombre del proyecto
  Project name
*/
variable "project_name" {
  description = "Nombre del proyecto / Project name"
  type        = string
}

/*
  Ambiente (dev, staging, prod)
  Environment (dev, staging, prod)
*/
variable "environment" {
  description = "Ambiente (dev, staging, prod) / Environment (dev, staging, prod)"
  type        = string
}

/*
  Tags comunes para todos los recursos
  Common tags for all resources
*/
variable "common_tags" {
  description = "Mapa de tags comunes / Common tags map"
  type        = map(string)
}

/*
  Sufijo para el dominio del User Pool (Hosted UI)
  Suffix for Cognito User Pool domain (Hosted UI)
  Ejemplo final: ${project_name}-${environment}-${domain_suffix}
*/
variable "domain_suffix" {
  description = "Sufijo del dominio de Cognito / Cognito domain suffix"
  type        = string
  default     = "auth"
}

/*
  Habilitar MFA para usuarios
  Enable MFA for users
*/
variable "enable_mfa" {
  description = "Habilitar MFA (OPTIONAL u OFF) / Enable MFA"
  type        = bool
  default     = false
}

/*
  Protección contra borrado del User Pool
  Deletion protection for the User Pool
*/
variable "deletion_protection" {
  description = "Habilitar protección de borrado del User Pool / Enable Cognito deletion protection"
  type        = bool
  default     = true
}

/*
  URLs de callback para la aplicación web
  Callback URLs for the web client
  Ejemplo: ["https://app.example.com/callback"]
*/
variable "callback_urls" {
  description = "Lista de URLs de callback para el cliente web / Web client callback URLs"
  type        = list(string)
}

/*
  URLs de logout para la aplicación web
  Logout URLs for the web client
*/
variable "logout_urls" {
  description = "Lista de URLs de logout para el cliente web / Web client logout URLs"
  type        = list(string)
}

/*
  Crear cliente móvil (opcional)
  Create mobile client (optional)
*/
variable "create_mobile_client" {
  description = "Crear un User Pool Client adicional para mobile / Create mobile client"
  type        = bool
  default     = false
}

/*
  URLs de callback para la app móvil (cuando create_mobile_client = true)
  Callback URLs for mobile client
*/
variable "mobile_callback_urls" {
  description = "Lista de URLs de callback para el cliente móvil / Mobile client callback URLs"
  type        = list(string)
  default     = []
}

/*
  URLs de logout para la app móvil
  Logout URLs for mobile client
*/
variable "mobile_logout_urls" {
  description = "Lista de URLs de logout para el cliente móvil / Mobile client logout URLs"
  type        = list(string)
  default     = []
}

/*
  Crear Identity Pool (opcional)
  Create Cognito Identity Pool (optional)
*/
variable "create_identity_pool" {
  description = "Crear Identity Pool para acceso directo a AWS / Create Cognito Identity Pool"
  type        = bool
  default     = false
}

/*
  ARN del bucket de reportes en S3
  S3 reports bucket ARN
  Usado en la policy del rol autenticado del Identity Pool
*/
variable "s3_reports_bucket_arn" {
  description = "ARN del bucket S3 donde se almacenan los reportes PDF / S3 reports bucket ARN"
  type        = string
  default     = ""
}

/*
  ARN de la Lambda para pre-signup trigger (opcional)
  Pre-signup trigger Lambda ARN (optional)
*/
variable "pre_signup_lambda_arn" {
  description = "ARN de la función Lambda para el trigger Pre Sign-up / Pre sign-up Lambda ARN"
  type        = string
  default     = ""
}

/*
  ARN de la Lambda para post-confirmation trigger (opcional)
  Post-confirmation trigger Lambda ARN (optional)
*/
variable "post_confirmation_lambda_arn" {
  description = "ARN de la función Lambda para el trigger Post Confirmation / Post confirmation Lambda ARN"
  type        = string
  default     = ""
}
