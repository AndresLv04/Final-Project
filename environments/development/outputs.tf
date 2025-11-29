
// VPC Outputs
output "vpc_id" {
  description = "ID of VPC"
  value       = module.vpc.vpc_id
}
output "vpc_cidr" {
  description = "CIDR of VPC"
  value       = module.vpc.vpc_cidr
}
output "public_subnet_id" {
  description = "ID of public subnet"
  value       = module.vpc.public_subnet_id
}

output "public_subnet_secondary_id" {
  description = "ID of public subnet"
  value       = module.vpc.public_subnet_secondary_id
}

output "private_subnet_id" {
  description = "ID of private subnet"
  value       = module.vpc.private_subnet_id
}
output "private_subnet_secondary_id" {
  description = "ID of second private subnet"
  value       = module.vpc.private_subnet_secondary_id
}

output "nat_gateway_ip" {
  description = "Public IP of NAT Gateway"
  value       = module.vpc.nat_gateway_public_ip
}
output "availability_zone" {
  description = "Used AZ"
  value       = module.vpc.availability_zone
}

// Security Groups Outputs
output "all_security_group_ids" {
  description = "Map of all security group IDs"
  value       = module.security_groups.all_security_group_ids
}

// S3 Outputs
output "data_bucket_name" {
  description = "Nombre del bucket de datos"
  value       = module.s3.data_bucket_name
}

output "data_bucket_arn" {
  description = "ARN del bucket de datos"
  value       = module.s3.data_bucket_arn
}

output "logs_bucket_name" {
  description = "Nombre del bucket de logs"
  value       = module.s3.logs_bucket_id
}

output "bucket_prefixes" {
  description = "Prefijos del bucket"
  value       = module.s3.bucket_prefixes
}

// SQS Outputs
output "sqs_main_queue_id" {
  description = "ID de la cola principal de SQS"
  value       = module.sqs.queue_id
}
output "sqs_dlq_id" {
  description = "ID de la Dead Letter Queue de SQS"
  value       = module.sqs.dlq_id
}
output "queue_url" {
  description = "URL de la cola principal"
  value       = module.sqs.queue_url
}
output "queue_arn" {
  description = "ARN de la cola principal"
  value       = module.sqs.queue_arn
}
output "dlq_url" {
  description = "URL del Dead Letter Queue"
  value       = module.sqs.dlq_url
}
output "alarm_topic_arn" {
  description = "ARN del SNS topic para alarmas"
  value       = module.sqs.alarm_topic_arn
}

// RDS Outputs
# RDS Outputs
output "db_endpoint" {
  description = "Endpoint de la base de datos"
  value       = module.rds.db_instance_endpoint
}

output "db_address" {
  description = "Hostname de la base de datos"
  value       = module.rds.db_instance_address
}

output "db_name" {
  description = "Nombre de la base de datos"
  value       = module.rds.db_name
}

output "db_connection_string" {
  description = "String de conexión"
  value       = module.rds.connection_string
  sensitive   = true
}

// Lambda Outputs
output "lambda_notify_function_name" {
  description = "Nombre de la Lambda de notificaciones"
  value       = module.lambda.notify_function_name
}
output "lambda_ingest_name" {
  description = "Nombre de Lambda Ingest"
  value       = module.lambda.ingest_function_name
}
output "lambda_notify_name" {
  description = "Nombre de Lambda Notify"
  value       = module.lambda.notify_function_name
}
output "lambda_pdf_name" {
  description = "Nombre de Lambda PDF"
  value       = module.lambda.pdf_function_name
}
output "pdf_function_arn" {
  description = "ARN de la Lambda que genera PDFs"
  value       = module.lambda.pdf_function_arn
}

// API Gateway Outputs
# API Gateway Outputs
output "api_endpoint" {
  description = "URL base del API"
  value       = module.api_gateway.api_endpoint
}
output "api_ingest_endpoint" {
  description = "URL del endpoint de ingesta"
  value       = module.api_gateway.ingest_endpoint
}
output "api_health_endpoint" {
  description = "URL del health check"
  value       = module.api_gateway.health_endpoint
}
output "api_pdf_endpoint" {
  description = "URL del endpoint de generación de PDF"
  value       = module.api_gateway.pdf_endpoint
}
output "api_key_value" {
  description = "API Key para laboratorios externos"
  value       = module.api_gateway.api_key_value
  sensitive   = true
}

# Notifications Outputs
output "sns_topic_arn" {
  description = "ARN del SNS topic result-ready"
  value       = module.notifications.sns_topic_arn
}
output "ses_email_identity" {
  description = "Email identity de SES (FROM)"
  value       = module.notifications.ses_identity
}
output "ses_template_name" {
  description = "Nombre del template de SES"
  value       = module.notifications.ses_template_name
}


// ECS Worker Outputs
output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = module.ecs_worker.cluster_name
}

output "ecs_service_name" {
  description = "Nombre del servicio ECS worker"
  value       = module.ecs_worker.service_name
}

output "ecs_task_definition_arn" {
  description = "ARN de la task definition del worker"
  value       = module.ecs_worker.task_definition_arn
}

output "ecs_log_group_name" {
  description = "Nombre del log group de ECS worker"
  value       = module.ecs_worker.log_group_name
}

// Cognito outputs
output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_web_client_id" {
  description = "Cognito Web Client ID"
  value       = module.cognito.web_client_id
}

output "cognito_web_client_secret" {
  description = "Cognito Web Client Secret"
  value       = module.cognito.web_client_secret
  sensitive   = true
}

output "cognito_hosted_ui_url" {
  description = "Cognito Hosted UI base URL"
  value       = module.cognito.hosted_ui_url
}

output "cognito_login_url" {
  description = "Cognito direct login URL"
  value       = module.cognito.login_url
}

output "cognito_logout_url" {
  description = "Cognito direct logout URL"
  value       = module.cognito.logout_url
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID (si está habilitado)"
  value       = module.cognito.identity_pool_id
}

output "cognito_authenticated_role_arn" {
  description = "IAM role ARN for authenticated Cognito users"
  value       = module.cognito.authenticated_role_arn
}


// ALB outputs
output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "DNS name del ALB"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID del ALB (para Route53)"
  value       = module.alb.alb_zone_id
}

output "portal_target_group_arn" {
  description = "Target Group ARN del portal (ECS)"
  value       = module.alb.portal_target_group_arn
}

output "alb_portal_url" {
  description = "URL base del patient portal detrás del ALB"
  value       = module.alb.portal_url
}

//Cloudfront
output "portal_url" {
  description = "URL base del patient portal detrás de CloudFront"
  value       = module.cloudfront_portal.portal_url
}


//ECS Portal
output "portal_ecr_repository" {
  description = "Portal ECR repository URL"
  value       = module.ecs_portal.ecr_repository_url
}

output "portal_service_name" {
  description = "Portal ECS service name"
  value       = module.ecs_portal.service_name
}

output "portal_log_group" {
  description = "Portal CloudWatch log group"
  value       = module.ecs_portal.log_group_name
}

output "portal_task_definition" {
  description = "Portal task definition ARN"
  value       = module.ecs_portal.task_definition_arn
}

