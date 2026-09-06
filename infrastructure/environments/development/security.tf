module "security_groups" {
  source = "../../modules/security-groups"

  project_display_name = "ProductionCloudReliabilityPlatform"
  environment          = local.environment
  vpc_id               = module.vpc.vpc_id

  alb_ingress_ipv4_cidrs = ["0.0.0.0/0"]
}
