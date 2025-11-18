
// VPC Outputs
output "vpc_id" {
  description = "ID of VPC"
  value       = module.vpc.vpc_id
}
output "vpc_cidr" {
  description = "CIDR of VPC"
  value       = module.vpc.vpc_cidr
}
output "public_subnet_id" {
  description = "ID of public subnet"
  value       = module.vpc.public_subnet_id
}
output "private_subnet_id" {
  description = "ID of private subnet"
  value       = module.vpc.private_subnet_id
}
output "nat_gateway_ip" {
  description = "Public IP of NAT Gateway"
  value       = module.vpc.nat_gateway_public_ip
}
output "availability_zone" {
  description = "Used AZ"
  value       = module.vpc.availability_zone
}

// Security Groups Outputs
output "all_security_group_ids" {
  description = "Map of all security group IDs"
  value = module.security_groups.all_security_group_ids 
}