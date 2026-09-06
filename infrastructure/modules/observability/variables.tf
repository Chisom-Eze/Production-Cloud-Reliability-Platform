variable "project_name" {
  description = "Project name used in observability resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "api_task_role_name" {
  description = "API ECS task role name that receives telemetry export permissions."
  type        = string
}

variable "worker_task_role_name" {
  description = "Worker ECS task role name that receives telemetry export permissions."
  type        = string
}

variable "alb_arn" {
  description = "Application Load Balancer ARN."
  type        = string
}

variable "target_group_arn" {
  description = "API target group ARN."
  type        = string
}

variable "rds_identifier" {
  description = "RDS instance identifier."
  type        = string
}

variable "queue_name" {
  description = "Main SQS queue name."
  type        = string
}

variable "dlq_name" {
  description = "Dead-letter SQS queue name."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "api_service_name" {
  description = "API ECS service name."
  type        = string
}

variable "worker_service_name" {
  description = "Worker ECS service name."
  type        = string
}

variable "api_log_group_name" {
  description = "API CloudWatch log group name."
  type        = string
}

variable "worker_log_group_name" {
  description = "Worker CloudWatch log group name."
  type        = string
}

variable "nginx_log_group_name" {
  description = "Nginx CloudWatch log group name."
  type        = string
}

variable "api_5xx_error_rate_alarm_percent" {
  description = "API target 5XX error-rate alarm threshold percentage."
  type        = number

  validation {
    condition     = var.api_5xx_error_rate_alarm_percent > 0 && var.api_5xx_error_rate_alarm_percent < 100
    error_message = "api_5xx_error_rate_alarm_percent must be greater than 0 and less than 100."
  }
}

variable "api_p95_latency_alarm_seconds" {
  description = "API p95 target response time alarm threshold in seconds."
  type        = number

  validation {
    condition     = var.api_p95_latency_alarm_seconds > 0
    error_message = "api_p95_latency_alarm_seconds must be greater than 0."
  }
}

variable "queue_oldest_message_age_alarm_seconds" {
  description = "Main queue oldest visible message age alarm threshold in seconds."
  type        = number

  validation {
    condition     = var.queue_oldest_message_age_alarm_seconds > 0
    error_message = "queue_oldest_message_age_alarm_seconds must be greater than 0."
  }
}

variable "rds_cpu_alarm_percent" {
  description = "RDS CPU utilization alarm threshold percentage."
  type        = number

  validation {
    condition     = var.rds_cpu_alarm_percent > 0 && var.rds_cpu_alarm_percent < 100
    error_message = "rds_cpu_alarm_percent must be greater than 0 and less than 100."
  }
}

variable "rds_free_storage_alarm_bytes" {
  description = "RDS free storage alarm threshold in bytes."
  type        = number

  validation {
    condition     = var.rds_free_storage_alarm_bytes > 0
    error_message = "rds_free_storage_alarm_bytes must be greater than 0."
  }
}

variable "tags" {
  description = "Tags applied to observability resources."
  type        = map(string)
  default     = {}
}
