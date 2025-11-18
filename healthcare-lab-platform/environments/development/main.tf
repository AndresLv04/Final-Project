locals {
  common_tags = {
    Project     = var.common.project_name
    Environment = var.common.environment
    Owner       = var.common.owner
    ManagedBy   = "Terraform"
  }
}

//Despliegue del módulo VPC
//Deployment of the VPC module
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  vpc_cidr             = var.vpc.vpc_cidr
  availability_zone    = var.vpc.availability_zone
  public_subnet_cidr   = var.vpc.public_subnet_cidrs
  private_subnet_cidr  = var.vpc.private_subnet_cidrs
  enable_dns_hostnames = var.vpc.enable_dns_hostnames
  enable_dns_support   = var.vpc.enable_dns_support
  enable_nat_gateway   = var.vpc.enable_nat_gateway
}

module "security_groups" {
  source = "../../modules/security_group"

  project_name = var.common.project_name
  environment  = var.common.environment
  owner        = var.common.owner

  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = var.vpc.vpc_cidr
  allowed_cidr_blocks = var.security_groups.allowed_cidr_blocks
  enable_ssh_access   = var.security_groups.enable_ssh_access
}