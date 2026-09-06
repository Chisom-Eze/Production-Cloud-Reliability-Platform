variable "project_name" {
  description = "Project name used for account security audit resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the account trail is created."
  type        = string
}

variable "audit_bucket_prefix" {
  description = "Prefix used for the dedicated CloudTrail audit bucket."
  type        = string
  default     = "production-cloud-reliability-audit-"
}

variable "cloudtrail_log_prefix" {
  description = "Optional prefix for CloudTrail log delivery inside the audit bucket."
  type        = string
  default     = "cloudtrail"
}

variable "tags" {
  description = "Tags applied to account security audit resources."
  type        = map(string)
  default     = {}
}

