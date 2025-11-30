# Common metadata
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "owner" {
  description = "Project owner"
  type        = string
}

# Main queue configuration
variable "visibility_timeout_seconds" {
  description = "Visibility timeout for messages once they are received"
  type        = number
  default     = 300
}

variable "message_retention_seconds" {
  description = "How long SQS retains messages before deleting them"
  type        = number
  default     = 1209600 # 14 days
}

variable "max_message_size" {
  description = "Maximum message size in bytes"
  type        = number
  default     = 262144 # 256 KB
}

variable "delay_seconds" {
  description = "Delay in seconds before a message becomes visible"
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time in seconds"
  type        = number
  default     = 20
}

# Dead-letter queue configuration
variable "max_receive_count" {
  description = "Number of receive attempts before moving message to DLQ"
  type        = number
  default     = 3
}

variable "dlq_message_retention_seconds" {
  description = "How long messages are retained in the DLQ"
  type        = number
  default     = 1209600 # 14 days
}

# Encryption settings
variable "enable_encryption" {
  description = "Enable server-side encryption for SQS queues"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption (null to use SQS managed key)"
  type        = string
  default     = null
}

# CloudWatch alarms configuration
variable "enable_cloudwatch_alarms" {
  description = "Create CloudWatch alarms for the SQS queues"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email address to receive SQS alarm notifications"
  type        = string
  default     = ""
}
