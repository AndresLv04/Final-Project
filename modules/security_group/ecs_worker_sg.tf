# Security group for ECS worker tasks (lab processors)
resource "aws_security_group" "ecs_worker" {
  name        = "${var.project_name}-${var.environment}-ecs-worker-sg"
  description = "Security group for ECS worker tasks"
  vpc_id      = var.vpc_id

  # No inbound rules: workers do not receive direct traffic

  # Allow all outbound traffic (RDS, S3, SQS, SNS, etc.)
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
