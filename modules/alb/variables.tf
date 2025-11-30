# Common variables (project metadata)
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

# Networking variables
variable "vpc_id" {
  type        = string
  description = "ID de la VPC donde se desplegará el ALB y el target group."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Lista de subnets públicas donde se ubicará el ALB."
}

variable "alb_security_group_id" {
  type        = string
  description = "ID del Security Group asociado al Application Load Balancer."
}

# ALB configuration
variable "enable_deletion_protection" {
  type        = bool
  description = "Habilita o deshabilita la protección contra borrado del ALB."
  default     = true
}

variable "idle_timeout" {
  type        = number
  description = "Tiempo de idle timeout del ALB en segundos."
  default     = 60
}

variable "container_port" {
  type        = number
  description = "Puerto en el que escucha el contenedor (Target Group)."
}

variable "health_check_path" {
  type        = string
  description = "Path HTTP que utilizará el ALB para los health checks."
  default     = "/health"
}

variable "enable_stickiness" {
  type        = bool
  description = "Indica si se habilita stickiness (lb_cookie) en el target group."
  default     = false
}

# SSL / HTTPS configuration
variable "certificate_arn" {
  type        = string
  description = "ARN del certificado ACM para HTTPS. Si está vacío, no se crea el listener HTTPS."
  default     = ""
}

variable "ssl_policy" {
  type        = string
  description = "Política SSL a usar en el listener HTTPS del ALB."
  default     = "ELBSecurityPolicy-2016-08"
}

# Access logs configuration (S3)
variable "access_logs_bucket" {
  type        = string
  description = "Nombre del bucket S3 donde se almacenarán los access logs del ALB."
  default     = ""
}

variable "enable_access_logs" {
  type        = bool
  description = "Habilita o deshabilita los access logs del ALB hacia S3."
  default     = false
}

# CloudWatch log group for ALB (optional)
variable "enable_cloudwatch_logs" {
  type        = bool
  description = "Indica si se crea el CloudWatch Log Group para el ALB."
  default     = false
}

# DNS (Route53) configuration
variable "route53_zone_id" {
  type        = string
  description = "ID de la zona hospedada de Route53 donde se creará el registro A del ALB. Vacío para no crear registro."
  default     = ""
}

variable "domain_name" {
  type        = string
  description = "Nombre de dominio (record A) asociado al ALB en Route53."
  default     = ""
}

# WAFv2 Web ACL configuration
variable "waf_web_acl_arn" {
  type        = string
  description = "ARN del WAFv2 Web ACL a asociar con el ALB. Vacío para no asociar WAF."
  default     = ""
}
