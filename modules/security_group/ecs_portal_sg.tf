
// ECS PORTAL SECURITY GROUP

// Para el servicio ECS que corre el portal web

resource "aws_security_group" "ecs_portal" {
  name        = "${var.project_name}-${var.environment}-ecs-portal-sg"
  description = "Security group para ECS Portal (Patient Portal)"
  vpc_id      = var.vpc_id

  // REGLAS DE ENTRADA
  // Solo permitir tráfico desde el ALB
  ingress {
    description     = "HTTP desde ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  // REGLAS DE SALIDA
  // Permitir salida a internet (para descargar paquetes, APIs externas)
  egress {
    description = "To RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTPS (for Cognito, APIs, etc.)
  egress {
    description = "HTTPS for Cognito and APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTP (for health checks, etc.)
  egress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ecs-portal-sg"
      Type = "ECS-Portal"
    }
  )
}