locals {
  project_name = "production-cloud-reliability-platform"

  standard_tags = {
    Owner       = "Chisom"
    Application = "ProductionCloudReliabilityPlatform"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

module "security_audit" {
  source = "../../modules/security-audit"

  project_name          = local.project_name
  aws_region            = var.aws_region
  audit_bucket_prefix   = var.audit_bucket_prefix
  cloudtrail_log_prefix = var.cloudtrail_log_prefix
  tags                  = local.standard_tags
}

