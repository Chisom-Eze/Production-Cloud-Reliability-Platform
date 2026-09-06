output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by availability zone."
  value = {
    for az, subnet in aws_subnet.public : az => subnet.id
  }
}

output "application_private_subnet_ids" {
  description = "Application-private subnet IDs keyed by availability zone."
  value = {
    for az, subnet in aws_subnet.application_private : az => subnet.id
  }
}

output "database_private_subnet_ids" {
  description = "Database-private subnet IDs keyed by availability zone."
  value = {
    for az, subnet in aws_subnet.database_private : az => subnet.id
  }
}

output "public_subnet_cidr_blocks" {
  description = "Public subnet CIDR blocks keyed by availability zone."
  value       = var.public_subnet_cidr_blocks
}

output "application_private_subnet_cidr_blocks" {
  description = "Application-private subnet CIDR blocks keyed by availability zone."
  value       = var.application_private_subnet_cidr_blocks
}

output "database_private_subnet_cidr_blocks" {
  description = "Database-private subnet CIDR blocks keyed by availability zone."
  value       = var.database_private_subnet_cidr_blocks
}

output "internet_gateway_id" {
  description = "Internet Gateway ID."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs keyed by availability zone."
  value = {
    for az, nat_gateway in aws_nat_gateway.this : az => nat_gateway.id
  }
}

output "public_route_table_id" {
  description = "Public route table ID."
  value       = aws_route_table.public.id
}

output "application_private_route_table_ids" {
  description = "Application-private route table IDs keyed by availability zone."
  value = {
    for az, route_table in aws_route_table.application_private : az => route_table.id
  }
}

output "database_private_route_table_ids" {
  description = "Database-private route table IDs keyed by availability zone."
  value = {
    for az, route_table in aws_route_table.database_private : az => route_table.id
  }
}
