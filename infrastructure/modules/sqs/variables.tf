variable "project_display_name" {
  description = "AWS-compatible project display name used in queue names."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.project_display_name))
    error_message = "project_display_name may contain only letters, numbers, underscores, and hyphens."
  }
}

variable "environment" {
  description = "Environment name used in queue names."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.environment))
    error_message = "environment may contain only letters, numbers, underscores, and hyphens."
  }
}

variable "visibility_timeout_seconds" {
  description = "How long a received message stays invisible before it can be retried."
  type        = number
  default     = 60

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds must be between 0 and 43200 seconds."
  }
}

variable "max_receive_count" {
  description = "Number of failed receives before a message is moved to the DLQ."
  type        = number
  default     = 3

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count must be between 1 and 1000."
  }
}

variable "message_retention_seconds" {
  description = "Main queue message retention period in seconds."
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds must be between 60 seconds and 14 days."
  }
}

variable "dlq_message_retention_seconds" {
  description = "DLQ message retention period in seconds."
  type        = number
  default     = 1209600

  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "dlq_message_retention_seconds must be between 60 seconds and 14 days."
  }

  validation {
    condition     = var.dlq_message_retention_seconds >= var.message_retention_seconds
    error_message = "dlq_message_retention_seconds must be greater than or equal to message_retention_seconds."
  }
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time for ReceiveMessage calls."
  type        = number
  default     = 20

  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "receive_wait_time_seconds must be between 0 and 20 seconds."
  }
}
