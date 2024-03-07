variable "cidr_public_subnet" {
  description = "CIDR block for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24"]  # Add more CIDR blocks if needed
}

variable "cidr_private_subnet" {
  description = "CIDR block for private subnets"
  type        = list(string)
  default     = ["10.0.2.0/24"]  # Add more CIDR blocks if needed
}

# Create AWS VPC in us-east-1
# CIDR - 10.0.0.0/16

resource "aws_vpc" "dummy_vpc-us-east-1" {
  cidr_block = "10.0.0.0/16"
  tags = {
     Name = "VPC: dummy_vpc-us-east-1"
  } 
}

# Setup public subnet
resource "aws_subnet" "dummy_public_subnets" {
  count      = length(var.cidr_public_subnet)
  vpc_id     = aws_vpc.dummy_vpc-us-east-1.id
  cidr_block = var.cidr_public_subnet[count.index]
  availability_zone = "us-east-1a"

  tags = {
    Name = "Subnet-Public : Public Subnet ${count.index + 1}"
  }
}

# Setup private subnet
resource "aws_subnet" "dummy_private_subnets" {
  count      = length(var.cidr_private_subnet)
  vpc_id     = aws_vpc.dummy_vpc-us-east-1.id
  cidr_block = var.cidr_private_subnet[count.index]
  availability_zone = "us-east-1a"

  tags = {
    Name = "Subnet-Private : Private Subnet ${count.index + 1}"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "dummy_public_internet_gateway" {
  vpc_id = aws_vpc.dummy_vpc-us-east-1.id
  tags = {
    Name = "IGW: For dummy_vpc-us-east-1"
  }
}

# Create public route table

resource "aws_route_table" "dummy_public_route_table" {
  vpc_id = aws_vpc.dummy_vpc-us-east-1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dummy_public_internet_gateway.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

# Create private route table

resource "aws_route_table" "dummy_private_route_table" {
  vpc_id = aws_vpc.dummy_vpc-us-east-1.id

  tags = {
    Name = "Private Route Table"
  }
}

# Associate public subnets with public route table

resource "aws_route_table_association" "dummy_public_subnet_association" {
  count          = length(aws_subnet.dummy_public_subnets)
  subnet_id      = aws_subnet.dummy_public_subnets[count.index].id
  route_table_id = aws_route_table.dummy_public_route_table.id
}

# Associate private subnets with private route table

resource "aws_route_table_association" "dummy_private_subnet_association" {
  count          = length(aws_subnet.dummy_private_subnets)
  subnet_id      = aws_subnet.dummy_private_subnets[count.index].id
  route_table_id = aws_route_table.dummy_private_route_table.id
}

# Create EIPs for NAT gateway
resource "aws_eip" "nat_eip" {
  count = length(var.cidr_private_subnet)
  domain = "vpc"
}

# Create NAT gateways
resource "aws_nat_gateway" "nat_gateway" {
  count      = length(var.cidr_private_subnet)
  depends_on = [aws_eip.nat_eip]
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id = aws_subnet.dummy_private_subnets[count.index].id
  tags = {
    Name = "Private NAT GW: For dummy_vpc-us-east-1"
  }
}

# Create route for private subnet to route traffic through NAT gateway
resource "aws_route" "private_nat_gateway_route" {
  count          = length(aws_subnet.dummy_private_subnets)
  route_table_id = aws_route_table.dummy_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
}
