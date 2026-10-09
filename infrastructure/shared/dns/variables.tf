variable "aws_region" {
  description = "AWS provider region for shared authoritative DNS resources."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "The shared DNS root is intentionally configured from us-east-1."
  }
}

variable "domain_name" {
  description = "Domain owned by the shared authoritative public hosted zone."
  type        = string
  default     = "chisomeze.online"

  validation {
    condition     = var.domain_name == "chisomeze.online"
    error_message = "The shared DNS root owns only chisomeze.online."
  }
}
