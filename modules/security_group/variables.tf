

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

# Variables de red
variable "vpc_id" {
  description = "ID de la VPC donde crear los security groups"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC (para reglas internas)"
  type        = string
}

//Variables específicas de security groups
//Specific variables for security groups
variable "allowed_cidr_blocks" {
  description = "CIDRs permitidos para acceso HTTPS al ALB (para restringir acceso)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Todo internet por defecto
}

variable "enable_ssh_access" {
  description = "Habilitar acceso SSH (solo para debugging en dev)"
  type        = bool
  default     = false
}