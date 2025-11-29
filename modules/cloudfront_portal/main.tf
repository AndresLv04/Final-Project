locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  comment = "${var.project_name}-${var.environment}-portal"
}

resource "aws_cloudfront_distribution" "portal" {
  enabled             = true
  comment             = "${var.project_name}-${var.environment}-portal"
  default_root_object = ""

  # si no tienes dominio personalizado, deja esto vacío/omitido
  aliases = []

  origin {
    domain_name = var.origin_domain_name   # <-- DNS del ALB que ya tienes (module.alb.alb_dns_name)
    origin_id   = "portal-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 80
      origin_protocol_policy = "http-only"   # ALB sólo expuesto en HTTP por ahora
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "portal-alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true   # usamos *.cloudfront.net, sin dominio propio
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
