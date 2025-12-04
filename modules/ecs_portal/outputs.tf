# ECR repository URL for portal images
output "ecr_repository_url" {
  description = "ECR repository URL for portal images"
  value       = aws_ecr_repository.portal.repository_url
}

# ECS service name for portal
output "service_name" {
  description = "ECS service name for the portal"
  value       = aws_ecs_service.portal.name
}

# ECS task definition ARN for portal
output "task_definition_arn" {
  description = "Task definition ARN for the portal service"
  value       = aws_ecs_task_definition.portal.arn
}

# CloudWatch log group name for portal
output "log_group_name" {
  description = "CloudWatch Log Group name for the portal"
  value       = aws_cloudwatch_log_group.portal.name
}
