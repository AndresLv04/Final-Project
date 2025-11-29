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

  vpc_cidr                      = var.vpc.vpc_cidr
  availability_zone             = var.vpc.availability_zone
  availability_zone_secondary   = var.vpc.availability_zone_secondary
  public_subnet_cidr            = var.vpc.public_subnet_cidrs
  public_subnet_cidr_secondary =  var.vpc.public_subnet_cidr_secondary
  private_subnet_cidr           = var.vpc.private_subnet_cidrs
  private_subnet_cidr_secondary = var.vpc.private_subnet_cidr_secondary
  enable_dns_hostnames          = var.vpc.enable_dns_hostnames
  enable_dns_support            = var.vpc.enable_dns_support
  enable_nat_gateway            = var.vpc.enable_nat_gateway
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

//Despliegue del módulo RDS
//Deployment of the RDS module
module "rds" {
  source = "../../modules/rds"

  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  //Network Settings
  vpc_id = module.vpc.vpc_id
  subnet_ids = [
    module.vpc.private_subnet_id,
    module.vpc.private_subnet_secondary_id
  ]
  security_group_ids = [module.security_groups.all_security_group_ids.rds_sg_id]

  //Database Settings
  db_name     = "healthcare_lab_db"
  db_username = "dbadmin"
  db_password = var.rds.db_password

  engine_version   = var.rds.engine_version
  parameter_family = var.rds.parameter_family

  // Intance Settings
  db_instance_class     = var.rds.db_instance_class
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  //Backup Settings
  backup_retention_period = var.rds.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  // High Availability Settings
  db_multi_az = var.rds.db_multi_az

  // Monitoring Settings
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true

  //Protection Settings
  deletion_protection = false
  skip_final_snapshot = true

  //Alarm Settings
  enable_cloudwatch_alarms = true
  alarm_sns_topic_arn      = module.sqs.alarm_topic_arn
}

//Despliegue del módulo Lambda
//Deployment of the Lambda module
module "lambda" {
  source = "../../modules/lambda"

  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  # Network Settings
  vpc_id = module.vpc.vpc_id
  subnet_ids = [
    module.vpc.private_subnet_id,
    module.vpc.private_subnet_secondary_id
  ]

  security_group_id = module.security_groups.all_security_group_ids.lambda_sg_id

  # S3 Settings
  s3_bucket_name = module.s3.data_bucket_name
  s3_bucket_arn  = module.s3.data_bucket_arn

  # SQS Settings
  sqs_queue_url = module.sqs.queue_url
  sqs_queue_arn = module.sqs.queue_arn

  # RDS Settings
  db_host     = module.rds.db_instance_address
  db_port     = module.rds.db_instance_port
  db_name     = module.rds.db_name
  db_username = module.rds.db_username
  db_password = var.rds.db_password

  # SNS
  sns_topic_arn = module.sqs.alarm_topic_arn

  # Lambda Settings (vienen del objeto var.lambda)
  lambda_runtime     = var.lambda.lambda_runtime
  lambda_timeout     = var.lambda.lambda_timeout
  lambda_memory_size = var.lambda.lambda_memory_size

  ses_email_identity    = var.notifications.ses_email_identity
  portal_url            = var.notifications.portal_url
  ses_configuration_set = module.notifications.ses_configuration_set
  # Logging Settings
  log_retention_days = 7
}

// Despliegue del módulo API Gateway
// Deployment of the API Gateway module
module "api_gateway" {
  source = "../../modules/api_gateway"

  # Common
  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  # Lambda Functions
  lambda_ingest_invoke_arn    = module.lambda.ingest_invoke_arn
  lambda_ingest_function_name = module.lambda.ingest_function_name
  lambda_pdf_invoke_arn       = module.lambda.pdf_invoke_arn
  lambda_pdf_function_name    = module.lambda.pdf_function_name

  # API Configuration
  api_throttle_rate_limit  = var.api_gateway.api_throttle_rate_limit  # 100 requests/segundo
  api_throttle_burst_limit = var.api_gateway.api_throttle_burst_limit # 200 burst
  api_quota_limit          = var.api_gateway.api_quota_limit          # 10,000 requests/día

  enable_api_key_required = var.api_gateway.enable_api_key_required
  enable_access_logs      = var.api_gateway.enable_access_logs
  log_retention_days      = var.api_gateway.log_retention_days

  # CORS
  cors_allow_origins = ["*"] # Cambiar en producción

  # Alarms
  alarm_sns_topic_arn = module.sqs.alarm_topic_arn

}

//Despliegue del módulo Notifications
//Deployment of the Notifications module
module "notifications" {
  source = "../../modules/notifications"

  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  lambda_notify_function_arn  = module.lambda.notify_function_arn
  lambda_notify_function_name = module.lambda.notify_function_name

  ses_email_identity        = var.notifications.ses_email_identity
  enable_ses_event_tracking = true

  portal_url    = var.notifications.portal_url
  support_email = var.notifications.support_email

  enable_sns_encryption = true
}

# ============================================
# ECR Repository for ECS Worker
# ============================================
# Repositorio donde se sube la imagen Docker del worker

resource "aws_ecr_repository" "worker" {
  name                 = "${var.common.project_name}-${var.common.environment}-worker"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

# Política de ciclo de vida: mantener solo las últimas 10 imágenes
resource "aws_ecr_lifecycle_policy" "worker" {
  repository = aws_ecr_repository.worker.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ============================================
# ECS WORKER MODULE
# ============================================
# Procesa los mensajes de la cola SQS y publica en SNS "result-ready"

module "ecs_worker" {
  source = "../../modules/ecs_worker"

  # Common
  project_name = var.common.project_name
  environment  = var.common.environment
  aws_region   = var.aws_region


  # Network
  vpc_id = module.vpc.vpc_id
  private_subnet_ids = [
    module.vpc.private_subnet_id,
    module.vpc.private_subnet_secondary_id
  ]

  # IMPORTANTE: usa la key real de tu módulo de security_groups
  # (si el mapa se llama distinto, cámbialo)
  worker_security_group_id = module.security_groups.all_security_group_ids.ecs_worker_sg_id

  # Container image (desde ECR)
  container_image = "${aws_ecr_repository.worker.repository_url}:latest"

  # Task sizing (Fargate)
  task_cpu    = var.ecs.task_cpu    # por ejemplo "512"
  task_memory = var.ecs.task_memory # por ejemplo "1024"

  # Scaling
  desired_count      = var.ecs.desired_count
  min_capacity       = var.ecs.min_capacity
  max_capacity       = var.ecs.max_capacity
  target_queue_depth = var.ecs.target_queue_depth

  # AWS resources (I/O)
  s3_bucket      = module.s3.data_bucket_name
  sqs_queue_url  = module.sqs.queue_url
  sqs_queue_arn  = module.sqs.queue_arn
  sqs_queue_name = module.sqs.queue_name # este output debe existir en tu módulo SQS
  # 👉 Este SNS es el de "result-ready", viene del módulo notifications
  sns_topic_arn = module.notifications.sns_topic_arn

  # Database (el worker también lee/escribe en RDS)
  db_host     = module.rds.db_instance_address
  db_port     = module.rds.db_instance_port
  db_name     = module.rds.db_name
  db_user     = module.rds.db_username
  db_password = var.rds.db_password

  depends_on = [
    module.rds,
    module.sqs,
    module.s3,
    module.notifications
  ]
  common_tags = local.common_tags
}

module "cognito" {
  source = "../../modules/cognito"

  # Datos comunes
  project_name = var.common.project_name
  environment  = var.common.environment
  common_tags  = local.common_tags

  # Configuración principal
  domain_suffix       = var.cognito.domain_suffix
  enable_mfa          = var.cognito.enable_mfa
  deletion_protection = var.cognito.deletion_protection

  callback_urls = var.cognito.callback_urls
  logout_urls   = var.cognito.logout_urls

  # Cliente móvil (lo podemos dejar desactivado al inicio)
  create_mobile_client = var.cognito.create_mobile_client
  mobile_callback_urls = var.cognito.mobile_callback_urls
  mobile_logout_urls   = var.cognito.mobile_logout_urls

  # Bucket donde se guardan los PDF de reportes
  # Identity Pool + S3 reports
  create_identity_pool  = var.cognito.create_identity_pool
  s3_reports_bucket_arn = module.s3.data_bucket_arn


  # Triggers de Lambda (por ahora vacíos)
  pre_signup_lambda_arn        = ""
  post_confirmation_lambda_arn = ""

}


module "alb" {
  source = "../../modules/alb"

  # Metadatos comunes
  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  # Red y seguridad
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = [module.vpc.public_subnet_id, module.vpc.public_subnet_secondary_id]
  alb_security_group_id = module.security_groups.alb_sg_id

  # Config ALB
  enable_deletion_protection = var.alb.enable_deletion_protection
  idle_timeout               = var.alb.idle_timeout
  container_port             = var.alb.container_port
  health_check_path          = var.alb.health_check_path
  enable_stickiness          = var.alb.enable_stickiness

  # HTTPS / logs / WAF
  ssl_policy             = var.alb.ssl_policy
  access_logs_bucket     = var.alb.access_logs_bucket
  enable_access_logs     = var.alb.enable_access_logs
  enable_cloudwatch_logs = var.alb.enable_cloudwatch_logs

  route53_zone_id = var.alb.route53_zone_id
  domain_name     = var.alb.domain_name
  waf_web_acl_arn = var.alb.waf_web_acl_arn
}

module "cloudfront_portal" {
  source = "../../modules/cloudfront_portal"

  project_name      = var.common.project_name
  environment       = var.common.environment
  origin_domain_name = module.alb.alb_dns_name   
}



# ===================================
# ECS Patient Portal (Fargate)
# ===================================

module "ecs_portal" {
  source = "../../modules/ecs_portal"

  # Datos comunes
  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner
  common_tags  = local.common_tags

  # Tamaño de la task / scaling
  task_cpu        = var.portal.task_cpu
  task_memory     = var.portal.task_memory
  container_image = var.portal.container_image
  desired_count   = var.portal.desired_count
  min_capacity    = var.portal.min_capacity
  max_capacity    = var.portal.max_capacity

  # ECS / networking
  ecs_cluster_id   = module.ecs_worker.cluster_id     # <-- ajusta si tu módulo del cluster se llama distinto
  ecs_cluster_name = module.ecs_worker.cluster_name   # idem
  private_subnet_ids = [module.vpc.private_subnet_id, module.vpc.private_subnet_secondary_id ]
  portal_security_group_id = module.security_groups.all_security_group_ids.ecs_portal_sg_id
  alb_target_group_arn     = module.alb.portal_target_group_arn  # <-- usa el output del TG del portal

  # Cognito
  cognito_user_pool_id = module.cognito.user_pool_id
  cognito_client_id    = module.cognito.web_client_id
  cognito_domain       = module.cognito.user_pool_domain

  app_url = module.cloudfront_portal.portal_url

  aws_region   = var.aws_region
  callback_url = "${module.cloudfront_portal.portal_url}/callback"
  logout_url   = module.cloudfront_portal.portal_url

  # Base de datos (RDS)
  db_host     = module.rds.db_instance_address 
  db_port     = module.rds.db_instance_port
  db_name     = module.rds.db_name
  db_user     = module.rds.db_username
  db_password = var.rds.db_password

  //Lambda pdf_generat
  pdf_lambda_function_name = module.lambda.pdf_function_name
  pdf_lambda_function_arn  = module.lambda.pdf_function_arn
}
