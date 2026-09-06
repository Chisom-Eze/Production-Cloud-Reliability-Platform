variable "cluster_name" {
  description = "ECS cluster name."
  type        = string

  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "cluster_name must not be empty."
  }
}

variable "api_service_name" {
  description = "API ECS service name."
  type        = string

  validation {
    condition     = length(trimspace(var.api_service_name)) > 0
    error_message = "api_service_name must not be empty."
  }
}

variable "worker_service_name" {
  description = "Worker ECS service name."
  type        = string

  validation {
    condition     = length(trimspace(var.worker_service_name)) > 0
    error_message = "worker_service_name must not be empty."
  }
}

variable "queue_name" {
  description = "SQS queue name used by the worker."
  type        = string

  validation {
    condition     = length(trimspace(var.queue_name)) > 0
    error_message = "queue_name must not be empty."
  }
}

variable "api_min_capacity" {
  description = "Minimum API ECS service desired count."
  type        = number
  default     = 1

  validation {
    condition     = var.api_min_capacity >= 1
    error_message = "api_min_capacity must be at least 1."
  }
}

variable "api_max_capacity" {
  description = "Maximum API ECS service desired count."
  type        = number
  default     = 4

  validation {
    condition     = var.api_max_capacity >= var.api_min_capacity
    error_message = "api_max_capacity must be greater than or equal to api_min_capacity."
  }
}

variable "worker_min_capacity" {
  description = "Minimum worker ECS service desired count. Must remain at least 1 because workers dispatch the transactional outbox."
  type        = number
  default     = 1

  validation {
    condition     = var.worker_min_capacity >= 1
    error_message = "worker_min_capacity must be at least 1."
  }
}

variable "worker_max_capacity" {
  description = "Maximum worker ECS service desired count."
  type        = number
  default     = 4

  validation {
    condition     = var.worker_max_capacity >= var.worker_min_capacity
    error_message = "worker_max_capacity must be greater than or equal to worker_min_capacity."
  }
}

variable "api_cpu_target_percent" {
  description = "API target tracking CPU utilization percentage."
  type        = number
  default     = 60

  validation {
    condition     = var.api_cpu_target_percent > 0 && var.api_cpu_target_percent < 100
    error_message = "api_cpu_target_percent must be greater than 0 and less than 100."
  }
}

variable "api_memory_target_percent" {
  description = "API target tracking memory utilization percentage."
  type        = number
  default     = 70

  validation {
    condition     = var.api_memory_target_percent > 0 && var.api_memory_target_percent < 100
    error_message = "api_memory_target_percent must be greater than 0 and less than 100."
  }
}

variable "worker_backlog_per_task_target" {
  description = "Target SQS visible backlog per running worker task. Choose from acceptable wait time divided by average processing time."
  type        = number

  validation {
    condition     = var.worker_backlog_per_task_target > 0
    error_message = "worker_backlog_per_task_target must be greater than 0."
  }
}

variable "api_scale_out_cooldown_seconds" {
  description = "API scale-out cooldown in seconds."
  type        = number
  default     = 60

  validation {
    condition     = var.api_scale_out_cooldown_seconds >= 0
    error_message = "api_scale_out_cooldown_seconds must be non-negative."
  }
}

variable "api_scale_in_cooldown_seconds" {
  description = "API scale-in cooldown in seconds."
  type        = number
  default     = 300

  validation {
    condition     = var.api_scale_in_cooldown_seconds >= 0
    error_message = "api_scale_in_cooldown_seconds must be non-negative."
  }
}

variable "worker_scale_out_cooldown_seconds" {
  description = "Worker scale-out cooldown in seconds."
  type        = number
  default     = 60

  validation {
    condition     = var.worker_scale_out_cooldown_seconds >= 0
    error_message = "worker_scale_out_cooldown_seconds must be non-negative."
  }
}

variable "worker_scale_in_cooldown_seconds" {
  description = "Worker scale-in cooldown in seconds."
  type        = number
  default     = 300

  validation {
    condition     = var.worker_scale_in_cooldown_seconds >= 0
    error_message = "worker_scale_in_cooldown_seconds must be non-negative."
  }
}
