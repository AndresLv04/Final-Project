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
    owner        = string
  })
}

variable "vpc" {
  description = "VPC configuration"
  type = object({
    vpc_cidr             = string
    availability_zone    = string
    public_subnet_cidrs  = string
    private_subnet_cidrs = string
    enable_dns_hostnames = bool
    enable_dns_support   = bool
    enable_nat_gateway   = bool
  })
}