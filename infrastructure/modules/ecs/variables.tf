variable "project_name" {
  description = "Project name used in ECS resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region for container runtime configuration."
  type        = string
}

variable "container_insights" {
  description = "ECS cluster Container Insights setting. Use enhanced when supported by the AWS provider and account."
  type        = string
  default     = "enhanced"

  validation {
    condition     = contains(["disabled", "enabled", "enhanced"], var.container_insights)
    error_message = "container_insights must be disabled, enabled, or enhanced."
  }
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

variable "amp_remote_write_endpoint" {
  description = "AMP Prometheus remote-write endpoint."
  type        = string
}

variable "application_subnet_ids" {
  description = "Private application subnet IDs for ECS tasks."
  type        = list(string)
}

variable "api_security_group_id" {
  description = "Security group ID for API ECS tasks."
  type        = string
}

variable "worker_security_group_id" {
  description = "Security group ID for worker ECS tasks and migration run tasks."
  type        = string
}

variable "api_target_group_arn" {
  description = "ALB target group ARN that receives Nginx traffic on port 80."
  type        = string
}

variable "api_execution_role_arn" {
  description = "API task execution role ARN."
  type        = string
}

variable "api_task_role_arn" {
  description = "API application task role ARN."
  type        = string
}

variable "worker_execution_role_arn" {
  description = "Worker task execution role ARN."
  type        = string
}

variable "worker_task_role_arn" {
  description = "Worker application task role ARN."
  type        = string
}

variable "database_host" {
  description = "RDS PostgreSQL DNS address."
  type        = string
}

variable "database_port" {
  description = "RDS PostgreSQL listener port."
  type        = number
}

variable "database_name" {
  description = "Application database name."
  type        = string
}

variable "database_secret_arn" {
  description = "RDS-managed Secrets Manager secret ARN with username and password JSON keys."
  type        = string
  sensitive   = true
}

variable "sqs_queue_url" {
  description = "Main SQS queue URL."
  type        = string
}

variable "artifact_bucket_name" {
  description = "S3 artifact bucket name."
  type        = string
}

variable "api_desired_count" {
  description = "Desired API service task count."
  type        = number
  default     = 1

  validation {
    condition     = var.api_desired_count >= 1
    error_message = "api_desired_count must be at least 1."
  }
}

variable "worker_desired_count" {
  description = "Desired worker service task count."
  type        = number
  default     = 1

  validation {
    condition     = var.worker_desired_count >= 1
    error_message = "worker_desired_count must be at least 1."
  }
}

variable "api_task_cpu" {
  description = "API task CPU units."
  type        = number
  default     = 512
}

variable "api_task_memory" {
  description = "API task memory in MiB."
  type        = number
  default     = 1024
}

variable "worker_task_cpu" {
  description = "Worker task CPU units."
  type        = number
  default     = 256
}

variable "worker_task_memory" {
  description = "Worker task memory in MiB."
  type        = number
  default     = 512
}

variable "adot_collector_cpu" {
  description = "ADOT collector container CPU units."
  type        = number
  default     = 64
}

variable "adot_collector_memory_reservation" {
  description = "ADOT collector container memory reservation in MiB."
  type        = number
  default     = 128
}

variable "api_container_cpu" {
  description = "FastAPI container CPU units within the API task."
  type        = number
  default     = 320
}

variable "nginx_container_cpu" {
  description = "Nginx container CPU units within the API task."
  type        = number
  default     = 128
}

variable "worker_container_cpu" {
  description = "Worker container CPU units within the worker task."
  type        = number
  default     = 192
}

variable "migration_task_cpu" {
  description = "Migration task CPU units."
  type        = number
  default     = 256
}

variable "migration_task_memory" {
  description = "Migration task memory in MiB."
  type        = number
  default     = 512
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 7
}

variable "platform_version" {
  description = "Fargate platform version. LATEST must resolve to Linux platform 1.4.0 or later for JSON-key secret injection."
  type        = string
  default     = "LATEST"
}

variable "job_processing_lease_seconds" {
  description = "Worker database processing lease duration."
  type        = number
  default     = 120
}

variable "outbox_claim_lease_seconds" {
  description = "Worker outbox claim lease duration."
  type        = number
  default     = 120
}

variable "sqs_visibility_timeout_seconds" {
  description = "SQS visibility timeout configured for the main queue."
  type        = number
  default     = 60
}

variable "sqs_visibility_heartbeat_seconds" {
  description = "Worker heartbeat interval for SQS visibility extension."
  type        = number
  default     = 30
}

variable "otel_traces_sampler_arg" {
  description = "Parent-based trace ID ratio sampler argument."
  type        = number
  default     = 0.1

  validation {
    condition     = var.otel_traces_sampler_arg >= 0 && var.otel_traces_sampler_arg <= 1
    error_message = "otel_traces_sampler_arg must be between 0 and 1."
  }
}

variable "worker_metrics_port" {
  description = "Loopback-only worker Prometheus metrics port scraped by the local ADOT sidecar."
  type        = number
  default     = 9464
}

variable "tags" {
  description = "Additional tags applied to ECS resources."
  type        = map(string)
  default     = {}
}
