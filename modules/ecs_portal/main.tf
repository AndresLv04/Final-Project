# ===================================
# ECS Portal - Main resources
# ===================================

# ECR Repository for Portal
resource "aws_ecr_repository" "portal" {
  name                 = "${var.project_name}-${var.environment}-portal"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.common_tags
}

resource "aws_ecr_lifecycle_policy" "portal" {
  repository = aws_ecr_repository.portal.name

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

# ===================================
# IAM Role for Task Execution
# ===================================

resource "aws_iam_role" "task_execution" {
  name = "${var.project_name}-${var.environment}-portal-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_ecr" {
  name = "ecr-access"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.portal.arn}:*"
      }
    ]
  })
}

# ===================================
# IAM Role for Task
# ===================================

resource "aws_iam_role" "task" {
  name = "${var.project_name}-${var.environment}-portal-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# Minimal permissions for Portal (logs)
resource "aws_iam_role_policy" "task_policy" {
  name = "portal-permissions"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.portal.arn}:*"
      }
    ]
  })
}

# ===================================
# ECS Task Definition
# ===================================

resource "aws_ecs_task_definition" "portal" {
  family                   = "${var.project_name}-${var.environment}-portal"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "portal"
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "COGNITO_USER_POOL_ID"
          value = var.cognito_user_pool_id
        },
        {
          name  = "COGNITO_CLIENT_ID"
          value = var.cognito_client_id
        },
        {
          name  = "COGNITO_DOMAIN"
          value = "${var.cognito_domain}.auth.${var.aws_region}.amazoncognito.com"
        },
        {
          name  = "COGNITO_REGION"
          value = var.aws_region
        },
        {
          name  = "PDF_LAMBDA_NAME"
          value = var.pdf_lambda_function_name
        },
        {
          name = "APP_URL"
          # URL base pública del portal (CloudFront o dominio propio)
          value = var.app_url
        },
        {
          name  = "CALLBACK_URL"
          value = var.callback_url
        },
        {
          name  = "LOGOUT_URL"
          value = var.logout_url
        },
        {
          name  = "DB_HOST"
          value = var.db_host
        },
        {
          name  = "DB_PORT"
          value = tostring(var.db_port)
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_user
        },
        {
          name  = "DB_PASSWORD"
          value = var.db_password
        },
        {
          name  = "PORT"
          value = "5000"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.portal.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "portal"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = var.common_tags
}

# ===================================
# ECS Service
# ===================================

resource "aws_ecs_service" "portal" {
  name            = "${var.project_name}-${var.environment}-portal"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.portal.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.portal_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "portal"
    container_port   = 5000
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100



  # Health check grace period for ALB
  health_check_grace_period_seconds = 60

  tags = var.common_tags

  depends_on = [
    aws_iam_role_policy.task_execution_ecr
  ]
}

# ===================================
# Auto Scaling
# ===================================

resource "aws_appautoscaling_target" "portal" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.portal.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale based on CPU
resource "aws_appautoscaling_policy" "portal_cpu" {
  name               = "${var.project_name}-${var.environment}-portal-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.portal.resource_id
  scalable_dimension = aws_appautoscaling_target.portal.scalable_dimension
  service_namespace  = aws_appautoscaling_target.portal.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70.0

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Scale based on Memory
resource "aws_appautoscaling_policy" "portal_memory" {
  name               = "${var.project_name}-${var.environment}-portal-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.portal.resource_id
  scalable_dimension = aws_appautoscaling_target.portal.scalable_dimension
  service_namespace  = aws_appautoscaling_target.portal.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 80.0

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
