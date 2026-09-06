locals {
  project_name = "production-cloud-reliability-platform"
  environment  = "development"

  standard_tags = {
    Owner       = "Chisom"
    Application = "ProductionCloudReliabilityPlatform"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  project_name = local.project_name
  environment  = local.environment

  vpc_cidr_block = "10.10.0.0/16"
  availability_zones = [
    "us-east-1a",
    "us-east-1b"
  ]

  public_subnet_cidr_blocks = {
    "us-east-1a" = "10.10.0.0/24"
    "us-east-1b" = "10.10.1.0/24"
  }

  application_private_subnet_cidr_blocks = {
    "us-east-1a" = "10.10.10.0/24"
    "us-east-1b" = "10.10.11.0/24"
  }

  database_private_subnet_cidr_blocks = {
    "us-east-1a" = "10.10.20.0/24"
    "us-east-1b" = "10.10.21.0/24"
  }

  nat_gateway_strategy = "single"
}
