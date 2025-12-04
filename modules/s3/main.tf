# S3 module for data and logs buckets
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  # Main data bucket name
  data_bucket_name = "${var.project_name}-${var.environment}-data"

  # Logs bucket name
  logs_bucket_name = "${var.project_name}-${var.environment}-logs"
}

# Logs bucket for S3 access logs
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

# Enable versioning on logs bucket
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Server-side encryption for logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access on logs bucket
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server access logging for data bucket (logs go to logs bucket)
resource "aws_s3_bucket_logging" "data" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.data.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "data-bucket-access-logs/"
}

# Lifecycle rules for logs bucket (delete old logs)
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Delete log objects after 90 days
    expiration {
      days = 90
    }

    # Delete non-current versions after 30 days
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Bucket policy to allow S3 logging service to write access logs
resource "aws_s3_bucket_policy" "logs_access" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
      # S3 must be able to write log objects under the target prefix
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

# Main data bucket for application data
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

# Enable versioning on data bucket
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# Server-side encryption for data bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      # Use SSE-KMS if KMS key is provided, otherwise SSE-S3
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }

    # Enable bucket keys to reduce KMS calls
    bucket_key_enabled = true
  }
}

# Block or allow public access based on configuration
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

# Lifecycle rules for data bucket (cost optimization)
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  count  = var.lifecycle_rules_enabled ? 1 : 0
  bucket = aws_s3_bucket.data.id

  # Rule for raw data under incoming/
  rule {
    id     = "incoming-lifecycle"
    status = "Enabled"

    filter {
      prefix = "incoming/"
    }

    # Transitions for current versions
    transition {
      days          = var.days_to_transition_ia
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.days_to_glacier
      storage_class = "GLACIER"
    }

    # Optional expiration for current versions
    dynamic "expiration" {
      for_each = var.days_to_expire > 0 ? [1] : []
      content {
        days = var.days_to_expire
      }
    }

    # Transitions for non-current versions
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    # Delete non-current versions after 90 days
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  # Rule for processed data under processed/
  rule {
    id     = "processed-lifecycle"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    # Keep processed data in STANDARD longer, then move to IA
    transition {
      days          = var.days_to_transition_ia * 2
      storage_class = "STANDARD_IA"
    }

    # Delete non-current versions after 180 days
    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }

  # Rule for reports under reports/
  rule {
    id     = "reports-lifecycle"
    status = "Enabled"

    filter {
      prefix = "reports/"
    }

    # Move PDFs to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Delete non-current PDF versions after 30 days
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Bucket policy to enforce HTTPS and server-side encryption
resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Deny any request not using HTTPS
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
      # Deny uploads without SSE
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

# CORS configuration for browser access to bucket
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
