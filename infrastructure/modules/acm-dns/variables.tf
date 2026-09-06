variable "application_domain_name" {
  description = "Fully qualified application domain name for the public ACM certificate."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", var.application_domain_name))
    error_message = "application_domain_name must be a fully qualified domain name."
  }
}

variable "route53_zone_id" {
  description = "Existing Route 53 public hosted zone ID used for ACM DNS validation records."
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.route53_zone_id))
    error_message = "route53_zone_id must look like an AWS Route 53 hosted zone ID."
  }
}
