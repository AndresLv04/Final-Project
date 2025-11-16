variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-1"
}

variable "common" {
  type = object({
    project_name = string
  })
}

variable "environment" {
  description = "deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}
