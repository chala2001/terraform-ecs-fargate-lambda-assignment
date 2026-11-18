# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # Needed so tasks can resolve AWS service names
  enable_dns_hostnames = true

  tags = { Name = "${var.name_prefix}-vpc" }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

# ---------- Subnets (one per AZ, created with count) ----------

# Public subnets: for the ALB and NAT Gateway only
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.name_prefix}-public-${var.azs[count.index]}" }
}

# Private subnets: for ECS tasks and Lambda (no public IPs)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = { Name = "${var.name_prefix}-private-${var.azs[count.index]}" }
}

# ---------- NAT: lets private subnets reach out, but nobody can reach in ----------

# Elastic IP: a fixed public IP for the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name_prefix}-nat-eip" }
}

# NAT Gateway: lives in a PUBLIC subnet, used by PRIVATE subnets
# One NAT for cost (production: one per AZ for high availability)
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags       = { Name = "${var.name_prefix}-nat" }
  depends_on = [aws_internet_gateway.this] # NAT needs the IGW to exist first
}

# ---------- Routing ----------

# Public route table: internet traffic → Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.name_prefix}-public-rt" }
}

# Private route table: internet traffic → NAT Gateway (outbound only)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id 
  }

  tags = { Name = "${var.name_prefix}-private-rt" }
}

# Attach the route tables to each subnet (these do not support tags)
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}