// VPC ENDPOINTS SECURITY GROUP (Opcional)

// Para VPC endpoints (acceso privado a servicios AWS)

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
  description = "Security group para VPC Endpoints"
  vpc_id      = var.vpc_id

  // REGLAS DE ENTRADA
  // Permitir HTTPS desde dentro de la VPC
  ingress {
    description = "HTTPS desde la VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] // Toda la VPC
  }

  // REGLAS DE SALIDA
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
      Type = "VPC-Endpoints"
    }
  )
}
