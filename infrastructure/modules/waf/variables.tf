variable "project_slug" {
  description = "Short AWS-name-safe project slug."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,32}[a-z0-9]$", var.project_slug))
    error_message = "project_slug must be 3-34 lowercase letters, numbers, or hyphens, and must not start or end with a hyphen."
  }
}

variable "environment" {
  description = "Environment name used in WAF resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,20}[a-z0-9]$", var.environment))
    error_message = "environment must be 3-22 lowercase letters, numbers, or hyphens, and must not start or end with a hyphen."
  }
}

variable "alb_arn" {
  description = "Regional Application Load Balancer ARN to associate with this Web ACL."
  type        = string
}

variable "rate_limit" {
  description = "Maximum requests per IP during the configured WAF rate-limit evaluation window."
  type        = number

  validation {
    condition     = var.rate_limit >= 100
    error_message = "rate_limit must be at least 100."
  }
}

variable "rate_limit_evaluation_window_seconds" {
  description = "WAF rate-limit evaluation window in seconds."
  type        = number
  default     = 300

  validation {
    condition     = contains([60, 120, 300, 600], var.rate_limit_evaluation_window_seconds)
    error_message = "rate_limit_evaluation_window_seconds must be one of 60, 120, 300, or 600."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period for WAF logs."
  type        = number

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 3653
    ], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "metric_name_prefix" {
  description = "CloudWatch metric name prefix for the Web ACL and WAF rules."
  type        = string
  default     = "prod-reliability-dev"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,128}$", var.metric_name_prefix))
    error_message = "metric_name_prefix must contain only letters, numbers, underscores, and hyphens."
  }
}

variable "common_rule_set_version" {
  description = "Explicit version for AWSManagedRulesCommonRuleSet. Query AWS for supported versions before deployment."
  type        = string
}

variable "known_bad_inputs_rule_set_version" {
  description = "Explicit version for AWSManagedRulesKnownBadInputsRuleSet. Query AWS for supported versions before deployment."
  type        = string
}

variable "sqli_rule_set_version" {
  description = "Explicit version for AWSManagedRulesSQLiRuleSet. Query AWS for supported versions before deployment."
  type        = string
}

variable "ip_reputation_rule_set_version" {
  description = "Explicit version for AWSManagedRulesAmazonIpReputationList. Query AWS for supported versions before deployment."
  type        = string
}
