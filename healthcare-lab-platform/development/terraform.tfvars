// Valores concretos para el entorno dev
// Concrete values for dev environment
aws_region = "us-east-1"

common = {
  description  = "Common settings such as project name and environment"
  project_name = "healthcare-lab-platform"
  environment  = "dev"
}

owner = "Team_Diego_and_Andres"

vpc = {
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = "10.0.1.0/24"
  private_subnet_cidrs = "10.0.2.0/24"
}
