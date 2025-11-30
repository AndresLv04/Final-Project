# Security group for the ECS service running the patient portal
resource "aws_security_group" "ecs_portal" {
  name        = "${var.project_name}-${var.environment}-ecs-portal-sg"
  description = "Security group for ECS Portal service"
  vpc_id      = var.vpc_id

  # Allow HTTP traffic only from the ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow outbound PostgreSQL traffic (typically to RDS)
  egress {
    description = "PostgreSQL outbound (to RDS)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound HTTPS (Cognito, external APIs, etc.)
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound HTTP if needed
  egress {
    description = "HTTP outbound"
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
