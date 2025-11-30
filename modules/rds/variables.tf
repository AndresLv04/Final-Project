// RDS MODULE - VARIABLES

// Variables comunes
variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}
variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}
variable "owner" {
  description = "Dueño del proyecto"
  type        = string
}

// Network Configuration
variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}
variable "subnet_ids" {
  description = "IDs de subnets privadas para RDS"
  type        = list(string)
}
variable "security_group_ids" {
  description = "IDs de security groups para RDS"
  type        = list(string)
}

// Database Configuration
variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "healthcaredb"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "El nombre debe empezar con letra y solo contener letras, números y guiones bajos."
  }
}
variable "db_username" {
  description = "Usuario master de la base de datos"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}
variable "db_password" {
  description = "Contraseña del usuario master"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 16
    error_message = "La contraseña debe tener al menos 16 caracteres."
  }
}
variable "db_port" {
  description = "Puerto de PostgreSQL"
  type        = number
  default     = 5432
}

# Instance Configuration
variable "db_instance_class" {
  description = "Tipo de instancia RDS"
  type        = string
  default     = "db.t3.micro"
}
variable "allocated_storage" {
  description = "Storage inicial en GB"
  type        = number
  default     = 20
}
variable "max_allocated_storage" {
  description = "Storage máximo para autoscaling (0 = deshabilitado)"
  type        = number
  default     = 100
}
variable "storage_type" {
  description = "Tipo de storage (gp2, gp3, io1)"
  type        = string
  default     = "gp3"
}
variable "storage_encrypted" {
  description = "Habilitar encriptación de storage"
  type        = bool
  default     = true
}
variable "kms_key_id" {
  description = "KMS key para encriptación (null = AWS managed)"
  type        = string
  default     = null
}

// Backup Configuration
variable "backup_retention_period" {
  description = "Días de retención de backups (0-35)"
  type        = number
  default     = 7
}
variable "backup_window" {
  description = "Ventana de backup (UTC)"
  type        = string
  default     = "03:00-04:00" # 3-4 AM UTC
}
variable "maintenance_window" {
  description = "Ventana de mantenimiento (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00" # Domingos 4-5 AM UTC
}
variable "preferred_backup_window" {
  description = "Ventana preferida para backups automáticos"
  type        = string
  default     = "03:00-06:00"
}

// High Availability
variable "db_multi_az" {
  description = "Habilitar Multi-AZ (alta disponibilidad)"
  type        = bool
  default     = false # false en dev para ahorrar costos
}

// Monitoring
variable "enabled_cloudwatch_logs_exports" {
  description = "Logs a exportar a CloudWatch"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}
variable "performance_insights_enabled" {
  description = "Habilitar Performance Insights"
  type        = bool
  default     = true
}
variable "performance_insights_retention_period" {
  description = "Días de retención de Performance Insights"
  type        = number
  default     = 7
}

// Deletion Protection
variable "deletion_protection" {
  description = "Protección contra eliminación accidental"
  type        = bool
  default     = false // false en dev, true en prod
}
variable "skip_final_snapshot" {
  description = "Saltar snapshot final al eliminar"
  type        = bool
  default     = true // true en dev, false en prod
}
variable "final_snapshot_identifier" {
  description = "Nombre del snapshot final"
  type        = string
  default     = null
}

# PostgreSQL specific
variable "engine_version" {
  description = "Versión de PostgreSQL"
  type        = string
}
variable "parameter_family" {
  description = "Family de parameter group"
  type        = string
}
variable "apply_immediately" {
  description = "Aplicar cambios inmediatamente (vs siguiente ventana)"
  type        = bool
  default     = false
}

# Monitoring Alarms
variable "enable_cloudwatch_alarms" {
  description = "Crear alarmas de CloudWatch"
  type        = bool
  default     = true
}
variable "alarm_sns_topic_arn" {
  description = "ARN del SNS topic para alarmas"
  type        = string
  default     = ""
}
