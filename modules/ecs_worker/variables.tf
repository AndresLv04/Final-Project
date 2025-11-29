# ============================================
# ECS WORKER MODULE - VARIABLES
# ============================================

# Common
variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "Región AWS"
  type        = string
}

variable "common_tags" {
  description = "Tags comunes para todos los recursos ECS"
  type        = map(string)
}

# Network
variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets privadas donde correrán las tareas Fargate"
  type        = list(string)
}

variable "worker_security_group_id" {
  description = "Security Group del servicio ECS worker"
  type        = string
}

# Container
variable "container_image" {
  description = "Imagen del contenedor (ECR URL)"
  type        = string
}

variable "task_cpu" {
  description = "CPU para la tarea Fargate (por ej. \"512\")"
  type        = string
}

variable "task_memory" {
  description = "Memoria para la tarea Fargate (por ej. \"1024\")"
  type        = string
}

# Scaling
variable "desired_count" {
  description = "Número deseado de tasks"
  type        = number
}

variable "min_capacity" {
  description = "Mínimo de tasks en auto scaling"
  type        = number
}

variable "max_capacity" {
  description = "Máximo de tasks en auto scaling"
  type        = number
}

variable "target_queue_depth" {
  description = "Mensajes promedio en cola SQS que disparan scaling"
  type        = number
}

# S3 / SQS / SNS
variable "s3_bucket" {
  description = "Bucket S3 donde están los resultados"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL de la cola SQS"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN de la cola SQS"
  type        = string
}

variable "sqs_queue_name" {
  description = "Nombre de la cola SQS (para métricas CW)"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN del topic SNS result-ready"
  type        = string
}

# Database
variable "db_host" {
  description = "Host de la base de datos"
  type        = string
}

variable "db_port" {
  description = "Puerto de la base de datos"
  type        = number
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
}

variable "db_user" {
  description = "Usuario de la base de datos"
  type        = string
}

variable "db_password" {
  description = "Password de la base de datos"
  type        = string
  sensitive   = true
}

variable "log_retention_days" {
  description = "Días de retención de logs en CloudWatch para el worker ECS"
  type        = number
  default     = 7
}