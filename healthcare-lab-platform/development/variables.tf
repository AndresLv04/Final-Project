variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-1"
}

variable "common" {
  type = object({
    project_name = string
    environment  = string
  })
}

variable "environment" {
  description = "deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  type        = string
  description = "ES: Propietario del sistema | EN: System owner"
}

variable "vpc_cidr" {
  type        = string
  description = "ES: CIDR de la VPC | EN: VPC CIDR block"
}

variable "public_subnet_cidr" {
  type        = string
  description = "ES: CIDR de la subred pública | EN: Public subnet CIDR"
}

variable "private_subnet_cidr" {
  type        = string
  description = "ES: CIDR de la subred privada | EN: Private subnet CIDR"
}
