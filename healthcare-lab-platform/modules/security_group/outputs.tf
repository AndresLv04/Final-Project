output "all_security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    alb_sg_id = aws_security_group.alb.id
    ecs_portal_sg_id = aws_security_group.ecs_portal.id
    rds_sg_id = aws_security_group.rds.id
    lambda_sg_id = aws_security_group.lambda.id
    ecs_worker_sg_id = aws_security_group.ecs_worker.id
    vpc_endpoints_sg_id = aws_security_group.vpc_endpoints.id
  }
}