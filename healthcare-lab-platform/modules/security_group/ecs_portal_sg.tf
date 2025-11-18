
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
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # ← Solo desde ALB SG
  }

  // REGLAS DE SALIDA
  // Permitir salida a internet (para descargar paquetes, APIs externas)
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
      Name = "${var.project_name}-${var.environment}-ecs-portal-sg"
      Type = "ECS-Portal"
    }
  )
}