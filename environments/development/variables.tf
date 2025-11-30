variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-1"
}

variable "common" {
  description = "Common settings such as project name and environment"
  type = object({
    project_name = string
    environment  = string
    owner        = string
  })
}

// VPC configuration
variable "vpc" {
  description = "VPC configuration"
  type = object({
    vpc_cidr                      = string
    availability_zone             = string
    availability_zone_secondary   = string
    public_subnet_cidrs           = string
    public_subnet_cidr_secondary  = string
    private_subnet_cidrs          = string
    private_subnet_cidr_secondary = string
    enable_dns_hostnames          = bool
    enable_dns_support            = bool
    enable_nat_gateway            = bool
  })
}

variable "security_groups" {
  description = "Security groups configuration"
  type = object({
    allowed_cidr_blocks = list(string)
    enable_ssh_access   = bool
  })
}

variable "s3" {
  description = "S3 configuration"
  type = object({
    enable_versioning       = bool
    lifecycle_rules_enabled = bool
    days_to_transition_ia   = number
    days_to_glacier         = number
    enable_access_logging   = bool
  })
}

variable "sqs" {
  description = "SQS configuration"
  type = object({
    sqs_visibility_timeout = number
    sqs_max_receive_count  = number
    enable_sqs_alarms      = bool
    alarm_email            = string
  })
}

variable "rds" {
  description = "RDS configuration"
  type = object({
    db_instance_class       = string
    db_password             = string
    db_multi_az             = bool
    alarm_sns_topic_arn     = string
    engine_version          = string
    parameter_family        = string
    backup_retention_period = number
  })
}

variable "lambda" {
  description = "Lambda configuration"
  type = object({
    lambda_runtime     = string
    lambda_timeout     = number
    lambda_memory_size = number
  })
}

variable "api_gateway" {
  description = "API Gateway configuration"
  type = object({
    api_throttle_rate_limit  = number # 100 requests/segundo
    api_throttle_burst_limit = number # 200 burst
    api_quota_limit          = number # 10,000 requests/día

    enable_api_key_required = bool
    enable_access_logs      = bool
    log_retention_days      = number

  })
}

variable "notifications" {
  description = "Notification settings"
  type = object({
    ses_email_identity = string
    portal_url         = string
    support_email      = string
  })
}

variable "ecs" {
  description = "ECS worker configuration"
  type = object({
    task_cpu           = string
    task_memory        = string
    desired_count      = number
    min_capacity       = number
    max_capacity       = number
    target_queue_depth = number
  })
}

variable "cognito" {
  description = "Configuración de Cognito (User Pool / Clients / Identity Pool)"
  type = object({
    domain_suffix       = string
    enable_mfa          = bool
    deletion_protection = bool

    callback_urls = list(string)
    logout_urls   = list(string)

    create_mobile_client = bool
    mobile_callback_urls = list(string)
    mobile_logout_urls   = list(string)

    create_identity_pool = bool
  })
}


# ============================================
# ALB configuration for Patient Portal
# ============================================
variable "alb" {
  description = "Application Load Balancer configuration for the patient portal"
  type = object({
    enable_deletion_protection = bool
    idle_timeout               = number
    container_port             = number
    health_check_path          = string
    enable_stickiness          = bool

    certificate_arn        = string
    ssl_policy             = string
    access_logs_bucket     = string
    enable_access_logs     = bool
    enable_cloudwatch_logs = bool

    route53_zone_id = string
    domain_name     = string
    waf_web_acl_arn = string
  })
}

# ===================================
# ECS Patient Portal configuration
# ===================================

variable "portal" {
  description = "Configuration for the Patient Portal ECS service"
  type = object({
    container_image = string
    task_cpu        = string
    task_memory     = string
    desired_count   = number
    min_capacity    = number
    max_capacity    = number
  })
}

