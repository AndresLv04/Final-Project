// Valores concretos para el entorno dev
// Concrete values for dev environment
aws_region = "us-east-1"

common = {
  description  = "Common settings such as project name and environment"
  project_name = "healthcare-lab-platform"
  environment  = "dev"
  owner        = "Andres and Diego"
}

// Configuración de la VPC
// VPC configuration
vpc = {
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = "10.0.1.0/24"
  private_subnet_cidrs = "10.0.2.0/24"
  availability_zone    = "us-east-1a"
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true
}

// Configuración de security groups
// Security groups configuration
security_groups = {
  allowed_cidr_blocks = ["0.0.0.0/0"]
  enable_ssh_access   = false
}

// Configuración de S3
// S3 configuration
s3 = {
  enable_versioning       = true
  lifecycle_rules_enabled = true
  days_to_transition_ia   = 90
  days_to_glacier         = 180
  enable_access_logging   = true
}

// Configuración de SQS
// SQS configuration
sqs = {
  sqs_visibility_timeout = 300
  sqs_max_receive_count  = 3
  enable_sqs_alarms      = true
  alarm_email            = "andreslopezv04@gmail.com"
}