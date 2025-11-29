
// BUCKET PRINCIPAL - MAIN DATA BUCKET


resource "aws_s3_bucket" "data" {
  bucket = local.data_bucket_name

  tags = merge(
    local.common_tags,
    {
      Name       = local.data_bucket_name
      Purpose    = "Healthcare Lab Data"
      Compliance = "HIPAA"
      DataType   = "PHI"
    }
  )
}

# Versionado del bucket de datos
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Encriptación del bucket de datos
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      // Si se proporciona KMS key, usar SSE-KMS, sino SSE-S3
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }

    // Forzar encriptación en todos los objetos
    bucket_key_enabled = true
  }
}

// Bloquear acceso público
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

# Lifecycle rules para optimizar costos
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  count  = var.lifecycle_rules_enabled ? 1 : 0
  bucket = aws_s3_bucket.data.id

  # Regla para archivos en incoming/ (datos crudos)
  rule {
    id     = "incoming-lifecycle"
    status = "Enabled"

    # Aplicar solo a objetos con este prefijo
    filter {
      prefix = "incoming/"
    }

    # Transiciones de storage class
    transition {
      days          = var.days_to_transition_ia
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.days_to_glacier
      storage_class = "GLACIER"
    }

    # Expiración (si está configurado)
    dynamic "expiration" {
      for_each = var.days_to_expire > 0 ? [1] : []
      content {
        days = var.days_to_expire
      }
    }

    # Limpiar versiones antiguas
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
  // Regla para archivos procesados
  rule {
    id     = "processed-lifecycle"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    # Datos procesados son más valiosos, mantenemos en STANDARD más tiempo
    transition {
      days          = var.days_to_transition_ia * 2 # 180 días
      storage_class = "STANDARD_IA"
    }

    # Versiones antiguas
    noncurrent_version_expiration {
      noncurrent_days = 180 # Más tiempo que incoming
    }
  }

  // Regla para reportes PDF
  rule {
    id     = "reports-lifecycle"
    status = "Enabled"

    filter {
      prefix = "reports/"
    }

    # Los PDFs se mantienen en STANDARD (los pacientes los descargan)
    # Pero movemos a IA después de un tiempo
    transition {
      days          = 30 # Después de 30 días, poca gente descarga
      storage_class = "STANDARD_IA"
    }

    # Limpiar versiones antiguas de PDFs
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

}

// Política del bucket (restrict access)
resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.data.arn,
          "${aws_s3_bucket.data.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = ["AES256", "aws:kms"]
          }
        }
      }
    ]
  })
}

# CORS configuration (si necesitas acceso desde navegador)
resource "aws_s3_bucket_cors_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = [
      "https://${var.project_name}-${var.environment}.example.com"
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

