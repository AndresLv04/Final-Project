// S3 MODULE - BUCKET FOR LOGS

// Locals para tags comunes y para el nombre el bucket
locals {
  common_tags = {
    Project = var.project_name
    Environment = var.environment
    Owner = var.owner
    ManagedBy = "Terraform"
  }

  # Nombre del bucket principal
  data_bucket_name = "${var.project_name}-${var.environment}-data"
  
  # Nombre del bucket de logs
  logs_bucket_name = "${var.project_name}-${var.environment}-logs"
}


// BUCKET DE LOGS (para access logs de otros buckets)

// Este bucket almacena los logs de acceso de otros buckets

resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket_name

  tags = merge(
    local.common_tags,
    {
      Name        = local.logs_bucket_name
      Purpose     = "Access Logs"
      Compliance  = "HIPAA"
    }
  )
}

# Habilitar versionado en bucket de logs
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Encriptación del bucket de logs
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # SSE-S3 para logs
    }
  }
}

# Bloquear acceso público del bucket de logs
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# Lifecycle para logs (borrar logs viejos para ahorrar costos)
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id = "delete-old-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Borrar logs después de 90 días
    expiration {
      days = 90
    }

    # Borrar versiones antiguas
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
