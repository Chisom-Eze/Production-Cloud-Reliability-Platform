variable "identifier" {
  description = "Unique RDS instance identifier."
  type        = string

  validation {
    condition     = length(var.identifier) >= 1 && length(var.identifier) <= 63
    error_message = "identifier must be between 1 and 63 characters."
  }
}

variable "db_subnet_group_name" {
  description = "Name for the RDS DB subnet group."
  type        = string
}

variable "database_name" {
  description = "Initial PostgreSQL database name."
  type        = string
}

variable "master_username" {
  description = "Master username. The password is managed by RDS and Secrets Manager."
  type        = string
  sensitive   = true
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage" {
  description = "Initial storage size in GiB."
  type        = number

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GiB for gp3 RDS storage."
  }
}

variable "max_allocated_storage" {
  description = "Maximum autoscaled storage size in GiB."
  type        = number

  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage
    error_message = "max_allocated_storage must be greater than or equal to allocated_storage."
  }
}

variable "subnet_ids" {
  description = "Private database subnet IDs for the DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "subnet_ids must include at least two subnets in different Availability Zones."
  }
}

variable "vpc_security_group_ids" {
  description = "Security group IDs attached to the RDS instance."
  type        = list(string)

  validation {
    condition     = length(var.vpc_security_group_ids) >= 1
    error_message = "At least one RDS security group is required."
  }
}

variable "backup_retention_period" {
  description = "Automated backup retention in days."
  type        = number

  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 1 and 35 days."
  }
}

variable "preferred_backup_window" {
  description = "Daily backup window in UTC, for example 03:00-04:00."
  type        = string
}

variable "deletion_protection" {
  description = "Whether RDS deletion protection is enabled."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Whether Terraform skips the final snapshot when destroying the DB instance."
  type        = bool
}

variable "multi_az" {
  description = "Whether the RDS instance runs with Multi-AZ standby."
  type        = bool
}

variable "auto_minor_version_upgrade" {
  description = "Whether minor engine upgrades may be applied automatically."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Whether modifications are applied immediately instead of during the maintenance window."
  type        = bool
  default     = false
}

variable "preferred_maintenance_window" {
  description = "Weekly maintenance window in UTC, for example sun:04:00-sun:05:00."
  type        = string
}

variable "enabled_cloudwatch_logs_exports" {
  description = "PostgreSQL log types exported to CloudWatch Logs."
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch Logs retention period for exported RDS logs."
  type        = number
  default     = 7

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 3653
    ], var.cloudwatch_log_retention_days)
    error_message = "cloudwatch_log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "enhanced_monitoring_interval" {
  description = "Enhanced Monitoring interval in seconds. Use 0 to disable."
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.enhanced_monitoring_interval)
    error_message = "enhanced_monitoring_interval must be one of 0, 1, 5, 10, 15, 30, or 60."
  }
}

variable "performance_insights_enabled" {
  description = "Whether RDS Performance Insights is enabled for supported instance classes."
  type        = bool
  default     = false
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days when enabled."
  type        = number
  default     = 7
}
