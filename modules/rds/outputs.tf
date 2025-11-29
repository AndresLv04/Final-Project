
// RDS MODULE - OUTPUTS
// Connection Info
output "db_instance_id" {
  description = "ID de la instancia RDS"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "ARN de la instancia RDS"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "Endpoint de conexión (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "Hostname del endpoint"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "Puerto de la base de datos"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Nombre de la base de datos"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "Usuario master"
  value       = aws_db_instance.main.username
  sensitive   = true
}

# Resource Names
output "db_subnet_group_name" {
  description = "Nombre del subnet group"
  value       = aws_db_subnet_group.main.name
}

output "parameter_group_name" {
  description = "Nombre del parameter group"
  value       = aws_db_parameter_group.main.name
}

# Monitoring
output "monitoring_role_arn" {
  description = "ARN del IAM role de monitoring"
  value       = aws_iam_role.rds_monitoring.arn
}

# Connection String
output "connection_string" {
  description = "String de conexión PostgreSQL"
  value       = "postgresql://${aws_db_instance.main.username}:***@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}?sslmode=require"
  sensitive   = true
}