//Definition of variables for the Healthcare Lab Platform Terraform configuration


//Define the AWS region variable where the resources will be deployed
//Define la región de AWS donde se desplegarán los recursos
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

//Define the project name variable for tagging resources
//Define la variable del nombre del proyecto para etiquetar los recursos
variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "healthcare-lab"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

//Define the VPC CIDR block variable
//Define la variable del bloque CIDR de la VPC
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

//Define the public subnet CIDR blocks variable
//Define la variable de los bloques CIDR de las subredes públicas
variable "public_subnet_cidrs" {
  description = "Public subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

//Define the private subnet CIDR blocks variable
//Define la variable de los bloques CIDR de las subredes privadas
variable "private_subnet_cidrs" {
  description = "Private subnet CIDR block"
  type        = string
  default     = "10.0.2.0/24"
}