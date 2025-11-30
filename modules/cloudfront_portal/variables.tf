# Project metadata
variable "project_name" {
  type        = string
  description = "Nombre del proyecto"
}

variable "environment" {
  type        = string
  description = "Ambiente (dev, staging, prod)"
}

# Origin configuration (ALB)
variable "origin_domain_name" {
  type        = string
  description = "DNS name del ALB (sin http://)"
}

variable "origin_path" {
  type        = string
  description = "Path opcional para el origen"
  default     = ""
}

# HTTP methods configuration
variable "allowed_http_methods" {
  type        = list(string)
  description = "Métodos HTTP permitidos en CloudFront"
  default     = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
}

variable "cached_http_methods" {
  type        = list(string)
  description = "Métodos HTTP que se cachean en CloudFront"
  default     = ["GET", "HEAD"]
}

