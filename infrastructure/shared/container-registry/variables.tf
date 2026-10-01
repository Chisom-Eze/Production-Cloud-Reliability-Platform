variable "aws_region" {
  description = "AWS region for shared container registry resources."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "The shared container registry is intentionally scoped to us-east-1."
  }
}

variable "github_development_ecr_publisher_role_name" {
  description = "Permanent GitHub development ECR publisher IAM role name created by bootstrap."
  type        = string
  default     = "pcrp-GitHubDevelopmentEcrPublisher"
}
