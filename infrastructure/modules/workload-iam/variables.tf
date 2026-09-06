variable "project_slug" {
  description = "Short IAM-safe project slug used in role names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,31}[a-z0-9]$", var.project_slug))
    error_message = "project_slug must be 3-33 lowercase letters, numbers, or hyphens, and must not start or end with a hyphen."
  }
}

variable "environment" {
  description = "Environment name used in role names."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,20}[a-z0-9]$", var.environment))
    error_message = "environment must be 3-22 lowercase letters, numbers, or hyphens, and must not start or end with a hyphen."
  }
}

variable "job_queue_arn" {
  description = "Main SQS job queue ARN."
  type        = string
}

variable "artifact_bucket_arn" {
  description = "Artifact S3 bucket ARN."
  type        = string
}

variable "artifact_object_prefix" {
  description = "Object prefix within the artifact bucket that worker permissions apply to."
  type        = string
  default     = "reports/*"

  validation {
    condition     = can(regex("^[^/].*\\*$", var.artifact_object_prefix))
    error_message = "artifact_object_prefix must be a relative object pattern ending in *."
  }
}

variable "database_secret_arn" {
  description = "RDS-managed Secrets Manager secret ARN used for ECS secret injection."
  type        = string
  sensitive   = true
}

variable "api_ecr_repository_arn" {
  description = "API ECR repository ARN."
  type        = string
}

variable "nginx_ecr_repository_arn" {
  description = "Nginx ECR repository ARN."
  type        = string
}

variable "worker_ecr_repository_arn" {
  description = "Worker ECR repository ARN."
  type        = string
}

variable "api_log_group_arn" {
  description = "Future API CloudWatch log group ARN."
  type        = string
}

variable "nginx_log_group_arn" {
  description = "Future Nginx CloudWatch log group ARN."
  type        = string
}

variable "worker_log_group_arn" {
  description = "Future worker CloudWatch log group ARN."
  type        = string
}
