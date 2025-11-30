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

# Network settings
variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block used for internal rules"
  type        = string
}

# Security group-specific variables
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB (HTTP/HTTPS)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_ssh_access" {
  description = "Enable SSH access (only for debugging in dev)"
  type        = bool
  default     = false
}
