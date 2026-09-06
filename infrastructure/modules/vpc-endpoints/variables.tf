variable "project_name" {
  description = "Project name used in endpoint tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
}

variable "aws_region" {
  description = "AWS region for regional endpoint service names."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID that owns the endpoint."
  type        = string
}

variable "application_private_route_table_ids" {
  description = "Application-private route table IDs that should receive the S3 Gateway Endpoint route."
  type        = list(string)

  validation {
    condition     = length(var.application_private_route_table_ids) > 0
    error_message = "At least one application-private route table ID is required."
  }
}

variable "artifact_bucket_arn" {
  description = "Application artifact bucket ARN."
  type        = string
}

variable "tags" {
  description = "Tags applied to endpoint resources."
  type        = map(string)
  default     = {}
}

