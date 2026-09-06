locals {
  name_prefix = "${var.project_name}-${var.environment}"

  nat_gateway_azs = (
    var.nat_gateway_strategy == "none" ? [] :
    var.nat_gateway_strategy == "single" && length(var.availability_zones) > 0 ? [var.availability_zones[0]] :
    var.availability_zones
  )

  application_nat_gateway_az = {
    for az in keys(var.application_private_subnet_cidr_blocks) :
    az => var.nat_gateway_strategy == "single" ? var.availability_zones[0] : az
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = var.public_subnet_cidr_blocks

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "application_private" {
  for_each = var.application_private_subnet_cidr_blocks

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-application-private-${each.key}"
    Tier = "application-private"
  }
}

resource "aws_subnet" "database_private" {
  for_each = var.database_private_subnet_cidr_blocks

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-database-private-${each.key}"
    Tier = "database-private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route" "public_default_ipv4" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_gateway_azs)

  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_gateway_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name = "${local.name_prefix}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "application_private" {
  for_each = var.application_private_subnet_cidr_blocks

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-application-private-rt-${each.key}"
  }
}

resource "aws_route" "application_private_default_ipv4" {
  for_each = var.nat_gateway_strategy == "none" ? {} : aws_route_table.application_private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[local.application_nat_gateway_az[each.key]].id
}

resource "aws_route_table_association" "application_private" {
  for_each = aws_subnet.application_private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.application_private[each.key].id
}

resource "aws_route_table" "database_private" {
  for_each = var.database_private_subnet_cidr_blocks

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-database-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "database_private" {
  for_each = aws_subnet.database_private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database_private[each.key].id
}
