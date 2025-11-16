locals {
  common_tags = {
    Project     = var.common.project_name
    Environment = var.common.environment
    Owner       = var.owner
  }
}

module "vpc" {
  source       = "../modules/vpc"
  project_name = var.common.project_name
  environment  = var.common.environment

  vpc_cidr             = var.vpc.vpc_cidr
  public_subnet_cidrs  = var.vpc.public_subnet_cidrs
  private_subnet_cidrs = var.vpc.private_subnet_cidrs
}
