module "acm_dns" {
  source = "../../modules/acm-dns"

  application_domain_name = var.application_domain_name
  route53_zone_id         = var.route53_zone_id
}

module "alb" {
  source = "../../modules/alb"

  project_slug = "prod-reliability"
  environment  = local.environment

  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = values(module.vpc.public_subnet_ids)
  alb_security_group_id = module.security_groups.alb_security_group_id

  certificate_arn = module.acm_dns.certificate_arn

  enable_deletion_protection = false
  access_log_retention_days  = 30
  access_log_prefix          = "alb"
  access_log_bucket_prefix   = "prod-reliability-dev-alb-logs-"

  health_check_path    = "/health"
  deregistration_delay = 30
  idle_timeout         = 60
}

resource "aws_route53_record" "application_alias" {
  name    = var.application_domain_name
  type    = "A"
  zone_id = var.route53_zone_id

  alias {
    evaluate_target_health = true
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
  }
}
