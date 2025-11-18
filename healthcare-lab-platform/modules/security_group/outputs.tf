output "all_security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    alb        = aws_security_group.alb.id
    ecs_portal = aws_security_group.ecs_portal.id
    rds        = aws_security_group.rds.id
    lambda     = aws_security_group.lambda.id
    ecs_worker = aws_security_group.ecs_worker.id
    vpc_endpoints = aws_security_group.vpc_endpoints.id
  }
}