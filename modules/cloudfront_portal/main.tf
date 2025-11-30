# Local values for common tags and distribution comment
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  comment = "${var.project_name}-${var.environment}-portal"
}

# CloudFront distribution in front of the ALB
resource "aws_cloudfront_distribution" "portal" {
  enabled             = true
  comment             = local.comment
  default_root_object = ""

  # No custom domain (uses default *.cloudfront.net)
  aliases = []

  # Origin pointing to the ALB
  origin {
    domain_name = var.origin_domain_name # ALB DNS (module.alb.alb_dns_name)
    origin_id   = "portal-alb-origin"
    origin_path = var.origin_path

    custom_origin_config {
      http_port              = 80
      https_port             = 80
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior for the portal
  default_cache_behavior {
    allowed_methods        = var.allowed_http_methods
    cached_methods         = var.cached_http_methods
    target_origin_id       = "portal-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }
  }

  # No geo restriction
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Use default CloudFront certificate (*.cloudfront.net)
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.common_tags
}
