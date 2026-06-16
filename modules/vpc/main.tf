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