//Security Groups Module - Application Load Balancer Security Group

// Locals para tags comunes
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

// ALB SECURITY GROUP

// Para el Application Load Balancer (puerta de entrada web)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group para Application Load Balancer"
  vpc_id      = var.vpc_id

  // REGLAS DE ENTRADA (Ingress)
  // Permitir tráfico HTTPS desde internet
  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Permitir tráfico HTTP (redirigir a HTTPS)
  ingress {
    description = "HTTP desde internet (para redirect a HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  // REGLAS DE SALIDA (Egress)

  # EGRESS: el ALB puede hablar hacia la VPC
  egress {
    description = "Salida a cualquier destino dentro de la VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
      Type = "ALB"
    }
  )
}