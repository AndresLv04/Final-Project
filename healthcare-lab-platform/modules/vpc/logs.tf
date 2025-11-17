//Esto captura todo el tráfico de red para auditoría
//This captures all network traffic for auditing
resource "aws_flow_log" "main" {

    vpc_id               = aws_vpc.main.id
    traffic_type         = "ALL"
    log_destination      = aws_cloudwatch_log_group.vpc_flow_log.arn
    log_destination_type = "cloud-watch-logs"
    iam_role_arn         = aws_iam_role.flow_log_role.arn
  

    tags = merge(
        local.common_tags,
        {
         Name = "${var.project_name}-${var.environment}-vpc-flow-log"
        }
    )
  
}

resource "aws_cloudwatch_log_group" "vpc_flow_log" {
    name = "${var.project_name}-${var.environment}-vpc-flow-logs"
    retention_in_days = 7 // Retain logs for 7 days
    
    tags = local.common_tags
}

//IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_log_role" {
    name = "${var.project_name}-${var.environment}-vpc-flow-log-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "vpc-flow-logs.amazonaws.com"
                }
            }
        ]
    })

    tags = local.common_tags
}

//IAM Politicas para el rol de VPC Flow Logs
//IAM Policy Attachment for VPC Flow Logs Role
resource "aws_iam_role_policy" "name" {
  name = "${var.project_name}-${var.environment}-vpc-flow-log-policy"
  role = aws_iam_role.flow_log_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

