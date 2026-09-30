# Create the project network and enable DNS features used by Kubernetes services.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# Remove the default security group's allow-all rules.
# EKS and RDS use their own security groups.
resource "aws_default_security_group" "this" {
  vpc_id  = aws_vpc.this.id
  ingress = []
  egress  = []

  tags = {
    Name    = "${var.project_name}-default-deny"
    Project = var.project_name
  }
}

# Public subnets host internet-facing load balancers and the NAT gateway.
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name                     = "${var.project_name}-public-${each.key}"
    Project                  = var.project_name
    "kubernetes.io/role/elb" = "1"
  }
}

# Private subnets keep worker nodes off public IPs while allowing outbound access via NAT.
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.project_name}-private-${each.key}"
    Project                           = var.project_name
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Provide the public subnets with a path to and from the internet.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

# Associate each public subnet with the internet-facing route table.
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Reserve a public IP address for the NAT gateway.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }
}

# A single NAT gateway provides outbound connectivity for all private subnets.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[sort(keys(var.public_subnets))[0]].id

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name    = "${var.project_name}-nat"
    Project = var.project_name
  }
}

# Route private-subnet internet-bound traffic through the NAT gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name    = "${var.project_name}-private-rt"
    Project = var.project_name
  }
}

# Apply the private route table to every private subnet.
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
