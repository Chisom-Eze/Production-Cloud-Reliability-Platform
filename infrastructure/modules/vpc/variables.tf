variable "project_name" {
  description = "Project name used in resource Name tags."
  type        = string
}

variable "environment" {
  description = "Environment name used in resource Name tags."
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used by the VPC subnets."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "At least one availability zone is required."
  }
}

variable "public_subnet_cidr_blocks" {
  description = "Map of availability zone to public subnet CIDR block."
  type        = map(string)

  validation {
    condition = (
      length(setsubtract(toset(var.availability_zones), toset(keys(var.public_subnet_cidr_blocks)))) == 0 &&
      length(setsubtract(toset(keys(var.public_subnet_cidr_blocks)), toset(var.availability_zones))) == 0
    )
    error_message = "public_subnet_cidr_blocks must contain exactly one entry for each availability zone."
  }
}

variable "application_private_subnet_cidr_blocks" {
  description = "Map of availability zone to private application subnet CIDR block."
  type        = map(string)

  validation {
    condition = (
      length(setsubtract(toset(var.availability_zones), toset(keys(var.application_private_subnet_cidr_blocks)))) == 0 &&
      length(setsubtract(toset(keys(var.application_private_subnet_cidr_blocks)), toset(var.availability_zones))) == 0
    )
    error_message = "application_private_subnet_cidr_blocks must contain exactly one entry for each availability zone."
  }
}

variable "database_private_subnet_cidr_blocks" {
  description = "Map of availability zone to private database subnet CIDR block."
  type        = map(string)

  validation {
    condition = (
      length(setsubtract(toset(var.availability_zones), toset(keys(var.database_private_subnet_cidr_blocks)))) == 0 &&
      length(setsubtract(toset(keys(var.database_private_subnet_cidr_blocks)), toset(var.availability_zones))) == 0
    )
    error_message = "database_private_subnet_cidr_blocks must contain exactly one entry for each availability zone."
  }
}

variable "nat_gateway_strategy" {
  description = "NAT Gateway strategy for application-private subnet egress. Valid values: single, per_az, none."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az", "none"], var.nat_gateway_strategy)
    error_message = "nat_gateway_strategy must be one of: single, per_az, none."
  }
}
