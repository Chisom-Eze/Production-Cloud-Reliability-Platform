variable "project_display_name" {
  description = "Project display name used for tags and default bucket prefix generation."
  type        = string

  validation {
    condition     = length(var.project_display_name) > 0
    error_message = "project_display_name must not be empty."
  }
}

variable "environment" {
  description = "Environment name used for tags and default bucket prefix generation."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", lower(var.environment)))
    error_message = "environment must contain only letters, numbers, and hyphens."
  }
}

variable "bucket_name_prefix" {
  description = "Optional lowercase S3 bucket prefix. Leave null to derive a short project/environment prefix."
  type        = string
  default     = null

  validation {
    condition = (
      var.bucket_name_prefix == null
      || can(regex("^[a-z0-9][a-z0-9-]{0,35}-$", var.bucket_name_prefix))
    )
    error_message = "bucket_name_prefix must be lowercase, S3-compatible, end with a hyphen, and be short enough for Terraform's generated suffix."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent object versions."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_retention_days > 0
    error_message = "noncurrent_version_retention_days must be greater than zero."
  }
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Number of days after which incomplete multipart uploads are aborted."
  type        = number
  default     = 7

  validation {
    condition     = var.abort_incomplete_multipart_upload_days > 0
    error_message = "abort_incomplete_multipart_upload_days must be greater than zero."
  }
}

variable "force_destroy" {
  description = "Whether Terraform may delete a non-empty artifact bucket."
  type        = bool
  default     = false
}
