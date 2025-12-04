# Security group for PostgreSQL RDS instance
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  # Allow PostgreSQL only from ECS portal, ECS workers and Lambda
  ingress {
    description = "PostgreSQL from ECS and Lambda"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
      aws_security_group.ecs_portal.id,
      aws_security_group.lambda.id,
      aws_security_group.ecs_worker.id
    ]
  }

  # Required egress rule (RDS typically does not initiate outbound connections)
  egress {
    description = "Allow all outbound traffic (required by AWS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
      Type = "RDS"
    }
  )
}
