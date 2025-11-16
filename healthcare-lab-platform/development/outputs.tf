output "vpc_id" {
    description = "ID of the VPC"
    value = module.vpc.vpc_id 
}

output "public_subnet_id" {
  value       = module.vpc.public_subnet_id
  description = "Public subnet ID"
}

output "private_subnet_id" {
  value       = module.vpc.private_subnet_id
  description = "Private subnet ID"
}