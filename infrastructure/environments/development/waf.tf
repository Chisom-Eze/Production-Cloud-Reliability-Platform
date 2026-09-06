module "waf" {
  source = "../../modules/waf"

  project_slug = "prod-reliability"
  environment  = local.environment
  alb_arn      = module.alb.alb_arn

  rate_limit                           = 2000
  rate_limit_evaluation_window_seconds = 300
  log_retention_days                   = 30
  metric_name_prefix                   = "prod-reliability-development"

  common_rule_set_version           = var.waf_common_rule_set_version
  known_bad_inputs_rule_set_version = var.waf_known_bad_inputs_rule_set_version
  sqli_rule_set_version             = var.waf_sqli_rule_set_version
  ip_reputation_rule_set_version    = var.waf_ip_reputation_rule_set_version
}
