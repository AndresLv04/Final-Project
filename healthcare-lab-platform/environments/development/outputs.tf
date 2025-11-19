
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