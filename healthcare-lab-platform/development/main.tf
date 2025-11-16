module "vpc" {
    source = "../modules/vpc"
    project_name = var.common.project_name
    environment = var.common.environment
    vpc_cidr = var.vpc_cidr
    public_subnet_cidrs  = var.public_subnet_cidr
    private_subnet_cidrs = var.private_subnet_cidr
}
