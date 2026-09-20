resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "Challenge-Main-VPC" }
}

# Private — hosts the ECS container instance
resource "aws_subnet" "app_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "${var.region}c"

  tags = { Name = "app-private-subnet" }
}

# Public — ALB requires 2+ AZs, so this is now two subnets, not one
resource "aws_subnet" "alb_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = { Name = "alb-public-a" }
}

resource "aws_subnet" "alb_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = { Name = "alb-public-b" }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "app-igw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = { Name = "app-public-rt" }
}

resource "aws_route_table_association" "alb_subnet_a_assoc" {
  subnet_id      = aws_subnet.alb_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "alb_subnet_b_assoc" {
  subnet_id      = aws_subnet.alb_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Private — no default route at all. Everything this subnet
# needs goes through VPC endpoints, not a gateway.
resource "aws_route_table" "target_private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "target-private-rt" }
}

resource "aws_route_table_association" "app_subnet_assoc" {
  subnet_id      = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.target_private.id
}