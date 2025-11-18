locals {
  common_tags = {
    Project     = var.common.project_name
    Environment = var.common.environment
    Owner       = var.common.owner
    ManagedBy   = "Terraform"
  }
}

//Despliegue del módulo VPC
//Deployment of the VPC module
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  vpc_cidr             = var.vpc.vpc_cidr
  availability_zone    = var.vpc.availability_zone
  public_subnet_cidr   = var.vpc.public_subnet_cidrs
  private_subnet_cidr  = var.vpc.private_subnet_cidrs
  enable_dns_hostnames = var.vpc.enable_dns_hostnames
  enable_dns_support   = var.vpc.enable_dns_support
  enable_nat_gateway   = var.vpc.enable_nat_gateway
}

//Despliegue del módulo Security Groups
//Deployment of the Security Groups module
module "security_groups" {
  source = "../../modules/security_group"

  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = var.vpc.vpc_cidr
  allowed_cidr_blocks = var.security_groups.allowed_cidr_blocks
  enable_ssh_access   = var.security_groups.enable_ssh_access
}

//Despliegue del módulo S3
//Deployment of the S3 module
module "s3" {
  source = "../../modules/s3"

  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  enable_versioning       = var.s3.enable_versioning
  lifecycle_rules_enabled = var.s3.lifecycle_rules_enabled
  days_to_transition_ia   = var.s3.days_to_transition_ia
  days_to_glacier         = var.s3.days_to_glacier
  days_to_expire          = 0

  enable_encryption     = true
  kms_key_id            = null
  block_public_access   = true
  enable_access_logging = var.s3.enable_access_logging
}

//Despliegue del módulo SQS
//Deployment of the SQS module
module "sqs" {
  source = "../../modules/sqs"

  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  //SQS Settings
  visibility_timeout_seconds = var.sqs.sqs_visibility_timeout
  max_receive_count          = var.sqs.sqs_max_receive_count
  receive_wait_time_seconds  = 20

  //Encryption Settings
  enable_encryption = true
  kms_key_id        = null

  //CloudWatch Alarms Settings
  enable_cloudwatch_alarms = var.sqs.enable_sqs_alarms
  alarm_email              = var.sqs.alarm_email
}