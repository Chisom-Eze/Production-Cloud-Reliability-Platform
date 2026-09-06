data "aws_caller_identity" "current" {}

locals {
  standard_tags = {
    Owner       = "Chisom"
    Application = "ProductionCloudReliabilityPlatform"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }

  ecr_repositories = {
    api    = "production-cloud-reliability-api"
    worker = "production-cloud-reliability-worker"
    nginx  = "production-cloud-reliability-nginx"
  }
}

module "ecr" {
  for_each = local.ecr_repositories

  source = "../../modules/ecr"

  repository_name = each.value
}
