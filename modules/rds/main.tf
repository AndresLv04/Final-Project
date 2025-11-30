# Common tags and RDS identifiers
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }

  db_identifier = "${var.project_name}-${var.environment}-postgres"

  # Final snapshot name when not skipped
  final_snapshot_identifier = var.skip_final_snapshot ? null : (
    var.final_snapshot_identifier != null ?
    var.final_snapshot_identifier :
    "${local.db_identifier}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  )
}

# AWS metadata data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# RDS subnet group
resource "aws_db_subnet_group" "main" {
  name       = "${local.db_identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${local.db_identifier}-subnet-group"
    }
  )
}

# PostgreSQL parameter group
resource "aws_db_parameter_group" "main" {
  name   = "${local.db_identifier}-params"
  family = var.parameter_family

  # Logging
  parameter {
    name         = "log_statement"
    value        = "all"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "1000"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Performance
  parameter {
    name         = "shared_buffers"
    value        = "{DBInstanceClassMemory/32768}"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "max_connections"
    value        = "100"
    apply_method = "pending-reboot"
  }

  # Security
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.db_identifier}-params"
    }
  )
}

# PostgreSQL RDS instance
resource "aws_db_instance" "main" {
  identifier = local.db_identifier

  # Engine
  engine         = "postgres"
  engine_version = var.engine_version

  # Instance sizing
  instance_class        = var.db_instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id

  # Database auth
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false

  # Parameter group
  parameter_group_name = aws_db_parameter_group.main.name

  # Backup and maintenance
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = local.final_snapshot_identifier

  # High availability
  multi_az = var.db_multi_az

  # Monitoring and insights
  enabled_cloudwatch_logs_exports       = var.enabled_cloudwatch_logs_exports
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Apply changes strategy
  apply_immediately = var.apply_immediately

  # Minor version upgrades
  auto_minor_version_upgrade = true

  # Tag snapshots
  copy_tags_to_snapshot = true

  tags = merge(
    local.common_tags,
    {
      Name       = local.db_identifier
      Engine     = "PostgreSQL"
      Version    = var.engine_version
      Compliance = "HIPAA"
    }
  )
}
