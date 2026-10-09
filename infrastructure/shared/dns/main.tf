locals {
  standard_tags = {
    Owner       = "Chisom"
    Application = "ProductionCloudReliabilityPlatform"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }
}

resource "aws_route53_zone" "authoritative" {
  name    = var.domain_name
  comment = "PCRP authoritative public DNS shared across environments."

  tags = local.standard_tags

  lifecycle {
    prevent_destroy = true
  }
}
