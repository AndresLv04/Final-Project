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
