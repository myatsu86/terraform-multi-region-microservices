resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  region     = var.region
  tags = {
    Name = var.name
  }
}

resource "aws_subnet" "this" {
  count                   = length(var.subnet_cidr)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidr[count.index]
  region                  = var.region
  availability_zone       = var.availability_zone[count.index]
  map_public_ip_on_launch = var.enable_igw
  tags = {
    Name = "${var.name}-subnet${count.index}"
  }
}

resource "aws_internet_gateway" "this" {
  count  = var.enable_igw ? 1 : 0
  vpc_id = aws_vpc.this.id
  region = var.region
  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_route_table" "this" {
  count  = var.enable_igw ? 1 : 0
  vpc_id = aws_vpc.this.id
  region = var.region

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }
  tags = {
    Name = "${var.name}-rt"
  }
}

resource "aws_route_table_association" "this" {
  count          = var.enable_igw ? length(var.subnet_cidr) : 0
  subnet_id      = aws_subnet.this[count.index].id
  route_table_id = aws_route_table.this[0].id
  region         = var.region
}

# NAT Gateway resources (enable_nat_gateway = true)
# subnet[0] = public subnet for the NAT GW itself (excluded from instance pool via outputs)
# subnet[1+] = private subnets for EC2 instances, route 0.0.0.0/0 through the NAT GW

resource "aws_internet_gateway" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.this.id
  region = var.region
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
  region = var.region
  tags   = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? 1 : 0
  subnet_id     = aws_subnet.this[0].id
  allocation_id = aws_eip.nat[0].id
  region        = var.region
  depends_on    = [aws_internet_gateway.nat]
  tags          = { Name = "${var.name}-nat" }
}

resource "aws_route_table" "nat_public" {
  count  = var.enable_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.this.id
  region = var.region
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nat[0].id
  }
  tags = { Name = "${var.name}-public-rt" }
}

resource "aws_route_table" "nat_private" {
  count  = var.enable_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.this.id
  region = var.region
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[0].id
  }
  tags = { Name = "${var.name}-private-rt" }
}

resource "aws_route_table_association" "nat_public" {
  count          = var.enable_nat_gateway ? 1 : 0
  subnet_id      = aws_subnet.this[0].id
  route_table_id = aws_route_table.nat_public[0].id
  region         = var.region
}

resource "aws_route_table_association" "nat_private" {
  count          = var.enable_nat_gateway ? length(var.subnet_cidr) - 1 : 0
  subnet_id      = aws_subnet.this[count.index + 1].id
  route_table_id = aws_route_table.nat_private[0].id
  region         = var.region
}