variable "aws_region" {
  description = "AWS region where the account security audit trail is created."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "The shared security audit root is intentionally created from us-east-1."
  }
}

variable "audit_bucket_prefix" {
  description = "Prefix used for the dedicated CloudTrail audit bucket."
  type        = string
  default     = "production-cloud-reliability-audit-"
}

variable "cloudtrail_log_prefix" {
  description = "Prefix for CloudTrail log delivery inside the audit bucket."
  type        = string
  default     = "cloudtrail"
}

