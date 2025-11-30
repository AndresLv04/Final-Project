# Common variables
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

# S3 configuration flags
variable "enable_versioning" {
  description = "Enable versioning on S3 buckets"
  type        = bool
  default     = true
}

variable "lifecycle_rules_enabled" {
  description = "Enable lifecycle rules on the data bucket"
  type        = bool
  default     = true
}

variable "days_until_transition" {
  description = "Number of days until transition to Glacier storage"
  type        = number
  default     = 90
}

variable "days_to_glacier" {
  description = "Number of days to keep objects before moving to Glacier"
  type        = number
  default     = 180
}

variable "days_to_expire" {
  description = "Days before expiring objects (0 = never expires)"
  type        = number
  default     = 0
}

variable "days_to_transition_ia" {
  description = "Days before moving objects to Infrequent Access"
  type        = number
  default     = 90
}

variable "enable_encryption" {
  description = "Enable encryption at rest for S3 objects"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for bucket encryption (null to use S3 managed keys)"
  type        = string
  default     = null
}

variable "block_public_access" {
  description = "Block all public access to the data bucket"
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "Enable server access logging for the data bucket"
  type        = bool
  default     = true
}
