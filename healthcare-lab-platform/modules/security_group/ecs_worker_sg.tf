
// ECS WORKER SECURITY GROUP


// Para los workers que procesan resultados de laboratorio

resource "aws_security_group" "ecs_worker" {
  name        = "${var.project_name}-${var.environment}-ecs-worker-sg"
  description = "Security group para ECS Workers (Lab Processors)"
  vpc_id      = var.vpc_id

  // REGLAS DE ENTRADA
  // Los workers NO reciben tráfico entrante (solo procesan desde SQS)
  // Por seguridad, no definimos ninguna regla ingress

/*
  REGLAS DE SALIDA
    Necesitan:
    - Acceder a RDS (PostgreSQL)
    - Acceder a S3 (vía VPC endpoint o internet)
    - Acceder a SQS
    - Acceder a SNS 
*/
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
      Name = "${var.project_name}-${var.environment}-ecs-worker-sg"
      Type = "ECS-Worker"
    }
  )
}