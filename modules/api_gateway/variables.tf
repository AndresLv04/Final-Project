# Common project variables
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

# Lambda functions for API integration
variable "lambda_ingest_invoke_arn" {
  description = "ARN de invocación de Lambda Ingest"
  type        = string
}

variable "lambda_ingest_function_name" {
  description = "Nombre de la función Lambda Ingest"
  type        = string
}

variable "lambda_pdf_invoke_arn" {
  description = "ARN de invocación de Lambda PDF"
  type        = string
}

variable "lambda_pdf_function_name" {
  description = "Nombre de la función Lambda PDF"
  type        = string
}

# API throttling and quota
variable "api_throttle_rate_limit" {
  description = "Requests por segundo"
  type        = number
  default     = 100
}

variable "api_throttle_burst_limit" {
  description = "Burst de requests"
  type        = number
  default     = 200
}

variable "api_quota_limit" {
  description = "Requests por día"
  type        = number
  default     = 10000
}

# API key requirement
variable "enable_api_key_required" {
  description = "Requerir API Key"
  type        = bool
  default     = true
}

# Access logs configuration
variable "enable_access_logs" {
  description = "Habilitar access logs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Días de retención de logs"
  type        = number
  default     = 7
}

# CORS configuration
variable "cors_allow_origins" {
  description = "Orígenes permitidos para CORS"
  type        = list(string)
  default     = ["*"]
}

# CloudWatch alarms SNS topic
variable "alarm_sns_topic_arn" {
  description = "ARN del SNS topic para alarmas"
  type        = string
  default     = ""
}
