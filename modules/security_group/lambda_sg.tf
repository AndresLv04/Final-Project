# Security group for Lambda functions running inside the VPC
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = var.vpc_id

  # No inbound rules: Lambda is invoked by AWS services, not directly

  # Allow all outbound traffic (RDS, S3, SQS, SNS, SES, external APIs)
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
