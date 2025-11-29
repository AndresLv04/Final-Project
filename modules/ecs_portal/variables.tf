# ===================================
# ECS Portal Module - Variables
# ===================================

# Proyecto / entorno / tags
variable "project_name" {
  description = "Nombre del proyecto / Project name"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod) / Environment"
  type        = string
}

variable "owner" {
  description = "Owner del proyecto / Project owner"
  type        = string
}

variable "common_tags" {
  description = "Mapa de tags comunes / Common tags map"
  type        = map(string)
}

# ===================================
# ECS task settings
# ===================================

variable "task_cpu" {
  description = "vCPU para la task de Fargate (por ejemplo 256, 512, 1024) / Fargate task CPU"
  type        = string
}

variable "task_memory" {
  description = "Memoria para la task de Fargate (por ejemplo 512, 1024, 2048) / Fargate task memory"
  type        = string
}

variable "container_image" {
  description = "Imagen del contenedor del portal (ECR) / Portal container image"
  type        = string
}

variable "desired_count" {
  description = "Número deseado de tasks para el portal / Desired ECS task count"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Capacidad mínima de auto scaling / Min ECS tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Capacidad máxima de auto scaling / Max ECS tasks"
  type        = number
  default     = 3
}

# ===================================
# Networking & ECS
# ===================================

variable "ecs_cluster_id" {
  description = "ID del cluster ECS donde se desplegará el portal / ECS cluster ARN or ID"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Nombre del cluster ECS (para métricas y alarms) / ECS cluster name"
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets privadas para las tasks Fargate / Private subnet IDs"
  type        = list(string)
}

variable "portal_security_group_id" {
  description = "Security group para el servicio ECS del portal / Portal ECS security group ID"
  type        = string
}

variable "alb_target_group_arn" {
  description = "ARN del Target Group del ALB que apunta al portal / ALB target group ARN"
  type        = string
}

variable "app_url" {
  description = "Base URL pública del portal (sin /callback)"
  type        = string
}


# ===================================
# Cognito & Auth
# ===================================

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID para el portal / User Pool ID"
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito User Pool web client ID / Web client ID"
  type        = string
}

variable "cognito_domain" {
  description = "Dominio de Cognito (sin https:// ni path) / Cognito domain prefix"
  type        = string
}

variable "aws_region" {
  description = "Región AWS donde se despliega el portal / AWS region"
  type        = string
}

variable "callback_url" {
  description = "Callback URL principal del portal (para login) / Main callback URL"
  type        = string
}

variable "logout_url" {
  description = "Logout URL principal del portal / Main logout URL"
  type        = string
}

# ===================================
# Database (RDS)
# ===================================

variable "db_host" {
  description = "Host de la base de datos / Database host"
  type        = string
}

variable "db_port" {
  description = "Puerto de la base de datos / Database port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Nombre de la base de datos / Database name"
  type        = string
}

variable "db_user" {
  description = "Usuario de la base de datos / Database user"
  type        = string
}

variable "db_password" {
  description = "Password de la base de datos / Database password"
  type        = string
  sensitive   = true
}


variable "pdf_lambda_function_name" {
  description = "Nombre de la Lambda que genera PDFs de resultados"
  type        = string
}

variable "pdf_lambda_function_arn" {
  description = "ARN de la Lambda que genera PDFs de resultados"
  type        = string
}
