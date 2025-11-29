# ============================================
# NOTIFICATIONS MODULE - VARIABLES
# ============================================

# Variables comunes
variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "owner" {
  description = "Dueño del proyecto"
  type        = string
}

# Lambda Notify
variable "lambda_notify_function_arn" {
  description = "ARN de Lambda Notify"
  type        = string
}

variable "lambda_notify_function_name" {
  description = "Nombre de Lambda Notify"
  type        = string
}

# SES Configuration
variable "ses_email_identity" {
  description = "Email verificado en SES (from address)"
  type        = string
}

variable "ses_configuration_set_name" {
  description = "Nombre del configuration set"
  type        = string
  default     = null
}

variable "enable_ses_event_tracking" {
  description = "Habilitar tracking de eventos (bounces, complaints)"
  type        = bool
  default     = true
}

# SNS Configuration
variable "enable_sns_encryption" {
  description = "Habilitar encriptación en SNS"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key para encriptación SNS"
  type        = string
  default     = null
}

# Email Templates
variable "portal_url" {
  description = "URL del portal de pacientes"
  type        = string
  default     = "https://portal.example.com"
}

variable "support_email" {
  description = "Email de soporte"
  type        = string
  default     = "support@example.com"
}