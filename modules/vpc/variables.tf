//Definition of variables for the Healthcare Lab Platform Terraform configuration


// VPC MODULE - VARIABLES


// Nombre del proyecto
// Name of the project
variable "project_name" {
  description = "Nombre del proyecto"
  type = string
}

// Ambiente (dev, staging, prod)
// Environment (dev, staging, prod)
variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type = string
}

// Dueño del proyecto
// Project owner
variable "owner" {
  description = "Dueño del proyecto"
  type = string
}

//Bloque CIDR para la VPC
//CIDR block for the VPC
variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  
  // Validación para asegurar que el CIDR es válido
  // Validation to ensure the CIDR is valid
  validation {
    condition = can(cidrhost(var.vpc_cidr, 0))
    error_message = "El vpc_cidr debe ser un CIDR válido."
  }
}

// Zona de disponibilidad a usar
// Availability zone to use
variable "availability_zone" {
  description = "Zona de disponibilidad a usar"
  type = string
}

// Bloque CIDR para la subnet pública
// CIDR block for the public subnet
variable "public_subnet_cidr" {
  description = "CIDR block para subnet pública"
  type = string
}

// Bloque CIDR para la subnet privada
// CIDR block for the private subnet
variable "private_subnet_cidr" {
  description = "CIDR block para subnet privada"
  type = string
}

// Crear NAT Gateway para subnet privada
// Create NAT Gateway for private subnet
variable "enable_nat_gateway" {
  description = "Crear NAT Gateway para subnet privada"
  type = bool
  default = true
}

// Habilitar DNS hostnames en la VPC
// Enable DNS hostnames in the VPC
variable "enable_dns_hostnames" {
  description = "Habilitar DNS hostnames en la VPC"
  type = bool
  default = true
}

variable "enable_dns_support" {
  description = "Habilitar DNS support en la VPC"
  type = bool
  default = true
}

// Segunda zona de disponibilidad (para la segunda subnet privada / RDS)
// Second AZ for the second private subnet (RDS)
variable "availability_zone_secondary" {
  description = "Segunda AZ para RDS"
  type        = string
}

// CIDR de la segunda subnet privada
// CIDR block for the second private subnet
variable "private_subnet_cidr_secondary" {
  description = "CIDR block para la segunda subnet privada"
  type        = string
}

variable "public_subnet_cidr_secondary" {
  description = "CIDR block for the secondary public subnet"
  type        = string
}
