
// LAMBDA SECURITY GROUP

// Para todas las funciones Lambda

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group para Lambda functions"
  vpc_id      = var.vpc_id

  // REGLAS DE ENTRADA
  // Lambda functions no reciben tráfico entrante directo
  // (son invocadas por eventos, API Gateway, etc.)

  /* 
    REGLAS DE SALIDA
    Necesitan acceso a:
     - RDS (para queries)
     - S3 (para leer/escribir archivos)
     - SQS (para enviar mensajes)
     - SNS/SES (para notificaciones)
     - Internet (para APIs externas) 
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
      Name = "${var.project_name}-${var.environment}-lambda-sg"
      Type = "Lambda"
    }
  )
}
