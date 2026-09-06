locals {
  name_prefix    = "${var.project_slug}-${var.environment}"
  log_group_name = "aws-waf-logs-${local.name_prefix}"
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = {
    Name = local.log_group_name
  }
}

resource "aws_wafv2_web_acl" "this" {
  name        = "${local.name_prefix}-web-acl"
  description = "Application-layer protection for ${local.name_prefix} ALB."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
        version     = var.common_rule_set_version
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.metric_name_prefix}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
        version     = var.known_bad_inputs_rule_set_version
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.metric_name_prefix}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
        version     = var.sqli_rule_set_version
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.metric_name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 40

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
        version     = var.ip_reputation_rule_set_version
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.metric_name_prefix}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "ApplicationIpRateLimit"
    priority = 50

    action {
      block {}
    }

    statement {
      rate_based_statement {
        aggregate_key_type    = "IP"
        evaluation_window_sec = var.rate_limit_evaluation_window_seconds
        limit                 = var.rate_limit
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.metric_name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.metric_name_prefix}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${local.name_prefix}-web-acl"
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.this.arn

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
