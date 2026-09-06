variable "project_display_name" {
  description = "Human-readable project name used in security group names and Name tags."
  type        = string
}

variable "environment" {
  description = "Environment name used in security group names and Name tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups are created."
  type        = string
}

variable "alb_ingress_ipv4_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach the public ALB listener."
  type        = list(string)

  validation {
    condition     = length(var.alb_ingress_ipv4_cidrs) > 0
    error_message = "At least one ALB ingress IPv4 CIDR is required."
  }
}

variable "alb_listener_port" {
  description = "Public ALB listener port."
  type        = number
  default     = 80

  validation {
    condition     = var.alb_listener_port >= 1 && var.alb_listener_port <= 65535
    error_message = "alb_listener_port must be between 1 and 65535."
  }
}

variable "alb_https_listener_port" {
  description = "Public ALB HTTPS listener port."
  type        = number
  default     = 443

  validation {
    condition     = var.alb_https_listener_port >= 1 && var.alb_https_listener_port <= 65535
    error_message = "alb_https_listener_port must be between 1 and 65535."
  }
}

variable "api_ingress_port" {
  description = "API task ingress port exposed to the ALB. This is the Nginx container port."
  type        = number
  default     = 80

  validation {
    condition     = var.api_ingress_port >= 1 && var.api_ingress_port <= 65535
    error_message = "api_ingress_port must be between 1 and 65535."
  }
}

variable "workload_https_egress_port" {
  description = "HTTPS egress port for API and worker access to AWS APIs and permitted external dependencies through NAT."
  type        = number
  default     = 443

  validation {
    condition     = var.workload_https_egress_port >= 1 && var.workload_https_egress_port <= 65535
    error_message = "workload_https_egress_port must be between 1 and 65535."
  }
}

variable "database_port" {
  description = "PostgreSQL database port."
  type        = number
  default     = 5432

  validation {
    condition     = var.database_port >= 1 && var.database_port <= 65535
    error_message = "database_port must be between 1 and 65535."
  }
}
