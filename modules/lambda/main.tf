# ============================================
# LAMBDA MODULE - MAIN
# ============================================

# Locals
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  lambda_prefix = "${var.project_name}-${var.environment}"
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ============================================
# 1. IAM ROLE PARA LAMBDAS
# ============================================

# Role base para todas las Lambdas
resource "aws_iam_role" "lambda_execution" {
  name = "${local.lambda_prefix}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# Policy para logs en CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy para VPC (si Lambda está en VPC)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Policy personalizada para S3, SQS, RDS
resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${local.lambda_prefix}-lambda-permissions"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arn
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SendTemplatedEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_topic_arn != "" ? var.sns_topic_arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.ingest.arn
      }
    ]
  })
}

# ============================================
# 2. LAMBDA LAYERS (Dependencias compartidas)
# ============================================

# Layer para psycopg2 (para conectar a PostgreSQL)
resource "aws_lambda_layer_version" "psycopg2" {
  filename            = "${path.module}/layers/psycopg2-layer.zip"
  layer_name          = "${local.lambda_prefix}-psycopg2"
  compatible_runtimes = [var.lambda_runtime]
  description         = "PostgreSQL adapter for Python - v2"

  # Este archivo debe ser creado previamente
  # Ver instrucciones en README
  lifecycle {
    ignore_changes = [filename]
  }
}

# ============================================
# Secrets Manager - credenciales de RDS
# ============================================

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "${local.lambda_prefix}-db-credentials"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    port     = var.db_port
    dbname   = var.db_name
  })
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${local.lambda_prefix}-secrets-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })
}

