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
    vpc_cidr             = string
    availability_zone    = string
    availability_zone_secondary = string
    public_subnet_cidrs  = string
    private_subnet_cidrs = string
    private_subnet_cidr_secondary = string
    enable_dns_hostnames = bool
    enable_dns_support   = bool
    enable_nat_gateway   = bool
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
    db_instance_class = string
    db_password = string
    db_multi_az = bool
    alarm_sns_topic_arn = string
    engine_version = string
    parameter_family = string
  })
}