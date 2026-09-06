variable "aws_region" {
  description = "AWS region for development resources."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "The development environment is intentionally scoped to us-east-1."
  }
}

variable "application_domain_name" {
  description = "Fully qualified development application domain name, for example app.chisomeze.online."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", var.application_domain_name))
    error_message = "application_domain_name must be a fully qualified domain name."
  }
}

variable "route53_zone_id" {
  description = "Existing Route 53 public hosted zone ID for the application domain."
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.route53_zone_id))
    error_message = "route53_zone_id must look like an AWS Route 53 hosted zone ID."
  }
}

variable "waf_common_rule_set_version" {
  description = "Explicit AWS-managed version for AWSManagedRulesCommonRuleSet. Query AWS before deployment."
  type        = string
}

variable "waf_known_bad_inputs_rule_set_version" {
  description = "Explicit AWS-managed version for AWSManagedRulesKnownBadInputsRuleSet. Query AWS before deployment."
  type        = string
}

variable "waf_sqli_rule_set_version" {
  description = "Explicit AWS-managed version for AWSManagedRulesSQLiRuleSet. Query AWS before deployment."
  type        = string
}

variable "waf_ip_reputation_rule_set_version" {
  description = "Explicit AWS-managed version for AWSManagedRulesAmazonIpReputationList. Query AWS before deployment."
  type        = string
}

variable "api_image_uri" {
  description = "Immutable API image URI in repository-uri@sha256:digest form."
  type        = string

  validation {
    condition     = can(regex("^.+@sha256:[0-9a-f]{64}$", var.api_image_uri)) && !can(regex(":latest@", var.api_image_uri))
    error_message = "api_image_uri must be an immutable digest reference like repository-uri@sha256:<64 lowercase hex characters> and must not use :latest."
  }
}

variable "nginx_image_uri" {
  description = "Immutable Nginx image URI in repository-uri@sha256:digest form."
  type        = string

  validation {
    condition     = can(regex("^.+@sha256:[0-9a-f]{64}$", var.nginx_image_uri)) && !can(regex(":latest@", var.nginx_image_uri))
    error_message = "nginx_image_uri must be an immutable digest reference like repository-uri@sha256:<64 lowercase hex characters> and must not use :latest."
  }
}

variable "worker_image_uri" {
  description = "Immutable worker image URI in repository-uri@sha256:digest form."
  type        = string

  validation {
    condition     = can(regex("^.+@sha256:[0-9a-f]{64}$", var.worker_image_uri)) && !can(regex(":latest@", var.worker_image_uri))
    error_message = "worker_image_uri must be an immutable digest reference like repository-uri@sha256:<64 lowercase hex characters> and must not use :latest."
  }
}

variable "adot_collector_image_uri" {
  description = "Immutable AWS Distro for OpenTelemetry collector image URI in repository-uri@sha256:digest form."
  type        = string

  validation {
    condition     = can(regex("^.+@sha256:[0-9a-f]{64}$", var.adot_collector_image_uri)) && !can(regex(":latest@", var.adot_collector_image_uri))
    error_message = "adot_collector_image_uri must be an immutable digest reference like repository-uri@sha256:<64 lowercase hex characters> and must not use :latest."
  }
}

variable "api_desired_count" {
  description = "Development API desired task count."
  type        = number
  default     = 1
}

variable "worker_desired_count" {
  description = "Development worker desired task count."
  type        = number
  default     = 1
}

variable "api_task_cpu" {
  description = "Development API task CPU units."
  type        = number
  default     = 512
}

variable "api_task_memory" {
  description = "Development API task memory in MiB."
  type        = number
  default     = 1024
}

variable "worker_task_cpu" {
  description = "Development worker task CPU units."
  type        = number
  default     = 256
}

variable "worker_task_memory" {
  description = "Development worker task memory in MiB."
  type        = number
  default     = 512
}

variable "adot_collector_cpu" {
  description = "Development ADOT collector container CPU units."
  type        = number
  default     = 64
}

variable "adot_collector_memory_reservation" {
  description = "Development ADOT collector memory reservation in MiB."
  type        = number
  default     = 128
}

variable "migration_task_cpu" {
  description = "Development one-off migration task CPU units."
  type        = number
  default     = 256
}

variable "migration_task_memory" {
  description = "Development one-off migration task memory in MiB."
  type        = number
  default     = 512
}

variable "api_min_capacity" {
  description = "Development API autoscaling minimum capacity."
  type        = number
  default     = 1

  validation {
    condition     = var.api_min_capacity >= 1
    error_message = "api_min_capacity must be at least 1."
  }
}

variable "api_max_capacity" {
  description = "Development API autoscaling maximum capacity."
  type        = number
  default     = 4

  validation {
    condition     = var.api_max_capacity >= var.api_min_capacity
    error_message = "api_max_capacity must be greater than or equal to api_min_capacity."
  }
}

variable "worker_min_capacity" {
  description = "Development worker autoscaling minimum capacity. Must remain at least 1 while the worker owns transactional-outbox dispatch."
  type        = number
  default     = 1

  validation {
    condition     = var.worker_min_capacity >= 1
    error_message = "worker_min_capacity must be at least 1."
  }
}

variable "worker_max_capacity" {
  description = "Development worker autoscaling maximum capacity."
  type        = number
  default     = 4

  validation {
    condition     = var.worker_max_capacity >= var.worker_min_capacity
    error_message = "worker_max_capacity must be greater than or equal to worker_min_capacity."
  }
}

variable "api_cpu_target_percent" {
  description = "Development API CPU target tracking percentage."
  type        = number
  default     = 60

  validation {
    condition     = var.api_cpu_target_percent > 0 && var.api_cpu_target_percent < 100
    error_message = "api_cpu_target_percent must be greater than 0 and less than 100."
  }
}

variable "api_memory_target_percent" {
  description = "Development API memory target tracking percentage."
  type        = number
  default     = 70

  validation {
    condition     = var.api_memory_target_percent > 0 && var.api_memory_target_percent < 100
    error_message = "api_memory_target_percent must be greater than 0 and less than 100."
  }
}

variable "worker_backlog_per_task_target" {
  description = "Required development worker backlog-per-task target, selected from acceptable queue wait time divided by average processing time."
  type        = number

  validation {
    condition     = var.worker_backlog_per_task_target > 0
    error_message = "worker_backlog_per_task_target must be greater than 0."
  }
}

variable "api_scale_out_cooldown_seconds" {
  description = "Development API scale-out cooldown in seconds."
  type        = number
  default     = 60

  validation {
    condition     = var.api_scale_out_cooldown_seconds >= 0
    error_message = "api_scale_out_cooldown_seconds must be non-negative."
  }
}

variable "api_scale_in_cooldown_seconds" {
  description = "Development API scale-in cooldown in seconds."
  type        = number
  default     = 300

  validation {
    condition     = var.api_scale_in_cooldown_seconds >= 0
    error_message = "api_scale_in_cooldown_seconds must be non-negative."
  }
}

variable "worker_scale_out_cooldown_seconds" {
  description = "Development worker scale-out cooldown in seconds."
  type        = number
  default     = 60

  validation {
    condition     = var.worker_scale_out_cooldown_seconds >= 0
    error_message = "worker_scale_out_cooldown_seconds must be non-negative."
  }
}

variable "worker_scale_in_cooldown_seconds" {
  description = "Development worker scale-in cooldown in seconds."
  type        = number
  default     = 300

  validation {
    condition     = var.worker_scale_in_cooldown_seconds >= 0
    error_message = "worker_scale_in_cooldown_seconds must be non-negative."
  }
}

variable "otel_traces_sampler_arg" {
  description = "Development parent-based trace ID ratio sampler argument."
  type        = number
  default     = 0.1

  validation {
    condition     = var.otel_traces_sampler_arg >= 0 && var.otel_traces_sampler_arg <= 1
    error_message = "otel_traces_sampler_arg must be between 0 and 1."
  }
}

variable "api_5xx_error_rate_alarm_percent" {
  description = "Required API target 5XX error-rate alarm threshold percentage."
  type        = number

  validation {
    condition     = var.api_5xx_error_rate_alarm_percent > 0 && var.api_5xx_error_rate_alarm_percent < 100
    error_message = "api_5xx_error_rate_alarm_percent must be greater than 0 and less than 100."
  }
}

variable "api_p95_latency_alarm_seconds" {
  description = "Required API p95 target response time alarm threshold in seconds."
  type        = number

  validation {
    condition     = var.api_p95_latency_alarm_seconds > 0
    error_message = "api_p95_latency_alarm_seconds must be greater than 0."
  }
}

variable "queue_oldest_message_age_alarm_seconds" {
  description = "Required main queue oldest visible message age alarm threshold in seconds."
  type        = number

  validation {
    condition     = var.queue_oldest_message_age_alarm_seconds > 0
    error_message = "queue_oldest_message_age_alarm_seconds must be greater than 0."
  }
}

variable "rds_cpu_alarm_percent" {
  description = "Required RDS CPU utilization alarm threshold percentage."
  type        = number

  validation {
    condition     = var.rds_cpu_alarm_percent > 0 && var.rds_cpu_alarm_percent < 100
    error_message = "rds_cpu_alarm_percent must be greater than 0 and less than 100."
  }
}

variable "rds_free_storage_alarm_bytes" {
  description = "Required RDS free storage alarm threshold in bytes."
  type        = number

  validation {
    condition     = var.rds_free_storage_alarm_bytes > 0
    error_message = "rds_free_storage_alarm_bytes must be greater than 0."
  }
}
