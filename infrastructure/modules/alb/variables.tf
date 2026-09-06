variable "project_slug" {
  description = "Short AWS-name-safe project slug."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,24}[a-z0-9]$", var.project_slug))
    error_message = "project_slug must be 3-26 lowercase letters, numbers, or hyphens, and must not start or end with a hyphen."
  }
}

variable "environment" {
  description = "Environment name used in resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,20}[a-z0-9]$", var.environment))
    error_message = "environment must be 3-22 lowercase letters, numbers, or hyphens, and must not start or end with a hyphen."
  }
}

variable "vpc_id" {
  description = "VPC ID for the API target group."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "public_subnet_ids must contain at least two subnets."
  }
}

variable "alb_security_group_id" {
  description = "Existing ALB security group ID."
  type        = string
}

variable "certificate_arn" {
  description = "Validated ACM certificate ARN for the HTTPS listener."
  type        = string
}

variable "enable_deletion_protection" {
  description = "Whether ALB deletion protection is enabled."
  type        = bool
}

variable "access_log_retention_days" {
  description = "Current and noncurrent ALB access-log retention in days."
  type        = number
  default     = 30

  validation {
    condition     = var.access_log_retention_days >= 30
    error_message = "access_log_retention_days must be at least 30 days."
  }
}

variable "access_log_prefix" {
  description = "Prefix used by ALB access logging before AWSLogs/account-id."
  type        = string
  default     = "alb"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.access_log_prefix))
    error_message = "access_log_prefix must be lowercase letters, numbers, or hyphens."
  }
}

variable "access_log_bucket_prefix" {
  description = "Optional lowercase S3 bucket prefix for the ALB access-log bucket."
  type        = string
  default     = null

  validation {
    condition = (
      var.access_log_bucket_prefix == null
      || can(regex("^[a-z0-9][a-z0-9-]{0,35}-$", var.access_log_bucket_prefix))
    )
    error_message = "access_log_bucket_prefix must be lowercase, S3-compatible, end with a hyphen, and be short enough for Terraform's generated suffix."
  }
}

variable "health_check_path" {
  description = "ALB target group health-check path."
  type        = string
  default     = "/health"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must start with /."
  }
}

variable "deregistration_delay" {
  description = "Target deregistration delay in seconds."
  type        = number
  default     = 30

  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "deregistration_delay must be between 0 and 3600 seconds."
  }
}

variable "idle_timeout" {
  description = "ALB idle timeout in seconds."
  type        = number
  default     = 60

  validation {
    condition     = var.idle_timeout >= 1 && var.idle_timeout <= 4000
    error_message = "idle_timeout must be between 1 and 4000 seconds."
  }
}

variable "tls_security_policy" {
  description = "ALB HTTPS listener TLS security policy."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
}
