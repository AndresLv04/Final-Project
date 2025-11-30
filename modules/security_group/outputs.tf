# Aggregated map with all security group IDs
output "all_security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    alb_sg_id           = aws_security_group.alb.id
    ecs_portal_sg_id    = aws_security_group.ecs_portal.id
    rds_sg_id           = aws_security_group.rds.id
    lambda_sg_id        = aws_security_group.lambda.id
    ecs_worker_sg_id    = aws_security_group.ecs_worker.id
    vpc_endpoints_sg_id = aws_security_group.vpc_endpoints.id
  }
}

# Individual ALB security group ARN
output "alb_sg_arn" {
  description = "ALB security group ARN"
  value       = aws_security_group.alb.arn
}

# Individual ECS Portal security group ARN
output "ecs_portal_sg_arn" {
  description = "ECS Portal security group ARN"
  value       = aws_security_group.ecs_portal.arn
}

# Individual ALB security group ID
output "alb_sg_id" {
  description = "Security group ID for the Application Load Balancer"
  value       = aws_security_group.alb.id
}

# Individual ECS Portal security group ID
output "ecs_portal_sg_id" {
  description = "Security group ID for the ECS portal service"
  value       = aws_security_group.ecs_portal.id
}
