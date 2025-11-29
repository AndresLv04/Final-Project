

// Cognito User Pool

resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-${var.environment}-patients"

  # Username configuration
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # User attributes schema
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = false

    string_attribute_constraints {
      min_length = 5
      max_length = 255
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 255
    }
  }

  schema {
    name                = "patient_id"
    attribute_data_type = "String"
    required            = false
    mutable             = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }

  schema {
    name                = "phone_number"
    attribute_data_type = "String"
    required            = false
    mutable             = true

    string_attribute_constraints {
      min_length = 10
      max_length = 20
    }
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Verification message templates
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Healthcare Lab - Verify your email"
    email_message        = "Your verification code is {####}"
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "AUDIT"
  }

  # MFA configuration (optional but recommended)
  mfa_configuration = var.enable_mfa ? "OPTIONAL" : "OFF"

  dynamic "software_token_mfa_configuration" {
    for_each = var.enable_mfa ? [1] : []
    content {
      enabled = true
    }
  }

  # Admin create user configuration
  admin_create_user_config {
    allow_admin_create_user_only = false

    invite_message_template {
      email_subject = "Healthcare Lab - Your temporary password"
      email_message = "Your username is {username} and temporary password is {####}"
      sms_message   = "Your username is {username} and temporary password is {####}"
    }
  }

  # Deletion protection
  deletion_protection = var.deletion_protection ? "ACTIVE" : "INACTIVE"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-user-pool"
    }
  )
}

# ===================================
# User Pool Domain (for Hosted UI)
# ===================================

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.environment}-${var.domain_suffix}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# ===================================
# User Pool Client (Web Application)
# ===================================

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project_name}-${var.environment}-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth flows
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  # Callback URLs (update these with your ALB URL)
  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  # Token validity
  id_token_validity      = 60    # 60 minutes
  access_token_validity  = 60    # 60 minutes
  refresh_token_validity = 30    # 30 days

  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "days"
  }

  # Read/Write attributes
  read_attributes = [
    "email",
    "email_verified",
    "name",
    "custom:patient_id",
    "phone_number"
  ]

  write_attributes = [
    "email",
    "name",
    "phone_number"
  ]

  # Security
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  # Explicit auth flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

# ===================================
# User Pool Client (Mobile/API - Optional)
# ===================================

resource "aws_cognito_user_pool_client" "mobile" {
  count = var.create_mobile_client ? 1 : 0

  name         = "${var.project_name}-${var.environment}-mobile-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth flows for mobile
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  # Mobile callback URLs
  callback_urls = var.mobile_callback_urls
  logout_urls   = var.mobile_logout_urls

  # Token validity
  id_token_validity      = 60
  access_token_validity  = 60
  refresh_token_validity = 90

  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "days"
  }

  read_attributes = [
    "email",
    "email_verified",
    "name",
    "custom:patient_id",
    "phone_number"
  ]

  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# ===================================
# Identity Pool (for direct AWS access - Optional)
# ===================================

resource "aws_cognito_identity_pool" "main" {
  count = var.create_identity_pool ? 1 : 0

  identity_pool_name               = "${var.project_name}_${var.environment}_identity_pool"
  allow_unauthenticated_identities = false
  allow_classic_flow               = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.web.id
    provider_name           = aws_cognito_user_pool.main.endpoint
    server_side_token_check = true
  }

  tags = var.common_tags
}

# IAM role for authenticated users (Identity Pool)
resource "aws_iam_role" "authenticated" {
  count = var.create_identity_pool ? 1 : 0

  name = "${var.project_name}-${var.environment}-cognito-authenticated"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main[0].id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Policy for authenticated users (minimal S3 access for PDFs)
resource "aws_iam_role_policy" "authenticated" {
  count = var.create_identity_pool ? 1 : 0

  name = "authenticated-user-policy"
  role = aws_iam_role.authenticated[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.s3_reports_bucket_arn}/reports/$${cognito-identity.amazonaws.com:sub}/*"
      }
    ]
  })
}

# Attach identity pool roles
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  count = var.create_identity_pool ? 1 : 0

  identity_pool_id = aws_cognito_identity_pool.main[0].id

  roles = {
    authenticated = aws_iam_role.authenticated[0].arn
  }
}

# ===================================
# User Pool Groups
# ===================================

resource "aws_cognito_user_group" "patients" {
  name         = "patients"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Standard patient users"
  precedence   = 1
}

resource "aws_cognito_user_group" "admins" {
  name         = "admins"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Administrative users"
  precedence   = 0
}

# ===================================
# CloudWatch Log Group for Cognito
# ===================================

resource "aws_cloudwatch_log_group" "cognito" {
  name              = "/aws/cognito/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = var.common_tags
}

# ===================================
# Lambda Triggers (Optional - for customization)
# ===================================

# Pre-signup trigger (validate email domain, etc.)
resource "aws_lambda_permission" "cognito_pre_signup" {
  count = var.pre_signup_lambda_arn != "" ? 1 : 0

  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.pre_signup_lambda_arn
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

# Post-confirmation trigger (send welcome email, etc.)
resource "aws_lambda_permission" "cognito_post_confirmation" {
  count = var.post_confirmation_lambda_arn != "" ? 1 : 0

  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.post_confirmation_lambda_arn
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

