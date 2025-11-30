locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}

//VPC Principal
//Main VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

// Internet Gateway para salida a Internet
// Internet Gateway for Internet access
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}
//Elastic IP para el NAT Gateway
//Elastic IP for the NAT Gateway
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

//Subred publica
//Public subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = var.availability_zone

  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-subnet-${var.availability_zone}"
      type = "Public"
      Tier = "Public"
    }
  )

}

# Segunda subred pública
# Second public subnet (for ALB HA)
resource "aws_subnet" "public_secondary" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr_secondary
  availability_zone = var.availability_zone_secondary

  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-subnet-${var.availability_zone_secondary}"
      type = "Public"
      Tier = "Public"
    }
  )
}

# Associate second public subnet with public route table
resource "aws_route_table_association" "public_secondary" {
  subnet_id      = aws_subnet.public_secondary.id
  route_table_id = aws_route_table.public.id
}



//Subred private
//Private subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  map_public_ip_on_launch = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-subnet-${var.availability_zone}"
      type = "Private"
      Tier = "Private"
    }
  )

}

//Segunda subred privada para RDS
//Second private subnet for RDS
resource "aws_subnet" "private_secondary" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_secondary
  availability_zone = var.availability_zone_secondary

  map_public_ip_on_launch = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-subnet-${var.availability_zone_secondary}"
      type = "Private"
      Tier = "Private"
    }
  )

}
//Asociación de la segunda subred privada a la tabla de ruteo privada
//Association of the second private subnet to the private route table
resource "aws_route_table_association" "private_secondary" {
  subnet_id      = aws_subnet.private_secondary.id
  route_table_id = aws_route_table.private.id
}


// NAT Gateway en la subred pública
// NAT Gateway in the public subnet
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-gateway"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

//Tabla de ruteo pública
//Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
      type = "Public"
    }
  )

}
# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

//Tabla de ruteo privada
//Private route private
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Solo agregar ruta si NAT Gateway está habilitado
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt"
      type = "Private"
    }
  )
}
# Associate private Subnets with private route table
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}