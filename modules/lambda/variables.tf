
// LAMBDA MODULE - VARIABLES


// Variables comunes
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

// Network
variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}
variable "subnet_ids" {
  description = "IDs de subnets privadas para Lambda"
  type        = list(string)
}
variable "security_group_id" {
  description = "ID del security group para Lambda"
  type        = string
}

// S3
variable "s3_bucket_name" {
  description = "Nombre del bucket S3 de datos"
  type        = string
}
variable "s3_bucket_arn" {
  description = "ARN del bucket S3"
  type        = string
}

# SQS
variable "sqs_queue_url" {
  description = "URL de la cola SQS"
  type        = string
}
// SQS
variable "sqs_queue_arn" {
  description = "ARN de la cola SQS"
  type        = string
}

# RDS
variable "db_host" {
  description = "Hostname de RDS"
  type        = string
}
variable "db_port" {
  description = "Puerto de RDS"
  type        = number
}
variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
}
variable "db_username" {
  description = "Usuario de la base de datos"
  type        = string
  sensitive   = true
}
variable "db_password" {
  description = "Contraseña de la base de datos"
  type        = string
  sensitive   = true
}

# SNS (para notify)
variable "sns_topic_arn" {
  description = "ARN del SNS topic"
  type        = string
  default     = ""
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Runtime de Lambda"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Timeout en segundos"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Memoria en MB"
  type        = number
  default     = 512
}

# Logging
variable "log_retention_days" {
  description = "Días de retención de logs"
  type        = number
  default     = 7
}

# SES / Notificaciones
variable "ses_email_identity" {
  description = "Dirección FROM para SES (Lambda notify)"
  type        = string
}

variable "portal_url" {
  description = "URL base del portal de pacientes"
  type        = string
}

variable "ses_configuration_set" {
  description = "Nombre del configuration set de SES"
  type        = string
  default     = null
}
