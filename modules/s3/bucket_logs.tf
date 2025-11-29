// S3 MODULE - BUCKET FOR LOGS

// Locals para tags comunes y para el nombre el bucket
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  // Nombre del bucket principal
  data_bucket_name = "${var.project_name}-${var.environment}-data"
  
  // Nombre del bucket de logs
  logs_bucket_name = "${var.project_name}-${var.environment}-logs"
}


// BUCKET DE LOGS (para access logs de otros buckets)
// This bucket stores access logs from other buckets
resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket_name

  tags = merge(
    local.common_tags,
    {
      Name       = local.logs_bucket_name
      Purpose    = "Access Logs"
      Compliance = "HIPAA"
    }
  )
}

// Habilitar versionado en bucket de logs / Enable versioning on logs bucket
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

// Encriptación del bucket de logs / Encryption for logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # SSE-S3 para logs
    }
  }
}

# Bloquear acceso público del bucket de logs / Block public access
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// Access logging (auditoría) para el bucket de datos
// Server access logging for data bucket  send logs to logs bucket
resource "aws_s3_bucket_logging" "data" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.data.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "data-bucket-access-logs/"
}

# Lifecycle para logs (borrar logs viejos para ahorrar costos)
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    // Borrar logs después de 90 días
    expiration {
      days = 90
    }

    // Borrar versiones antiguas
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

// Bucket policy para permitir que el servicio de S3 escriba access logs
// Bucket policy to allow S3 logging service to write access logs
resource "aws_s3_bucket_policy" "logs_access" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 necesita leer el ACL del bucket de logs
      # S3 needs to read bucket ACL
      {
        Sid    = "S3ServerAccessLogsAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs.arn
      },

      // S3 necesita poder escribir los objetos de log en el prefijo
      // S3 must be able to put log objects under the target prefix
      {
        Sid    = "S3ServerAccessLogsWrite"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/data-bucket-access-logs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
