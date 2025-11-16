variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-1"
}

variable "common" {
  description = "Common settings such as project name and environment"
  type = object({
    project_name = string
    environment  = string
  })
}

variable "owner" {
  type        = string
  description = "System owner"
}

variable "vpc" {
  description = "VPC settings such as CIDR blocks for VPC and subnets"
  type = object({
    vpc_cidr             = string
    public_subnet_cidrs  = string
    private_subnet_cidrs = string
  })
}