variable "aws_region" {
  description = "AWS region for bootstrap resources."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "Bootstrap is intentionally scoped to us-east-1."
  }
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform remote state."
  type        = string
}

variable "github_oidc_issuer_url" {
  description = "GitHub Actions OIDC issuer URL."
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "github_oidc_audience" {
  description = "Expected audience claim for GitHub Actions AWS federation."
  type        = string
  default     = "sts.amazonaws.com"
}

variable "github_development_subject" {
  description = "Exact GitHub OIDC subject allowed to assume the development deployment role."
  type        = string
}

