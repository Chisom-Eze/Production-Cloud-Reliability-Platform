output "audit_bucket_id" {
  description = "Dedicated CloudTrail audit bucket ID."
  value       = module.security_audit.audit_bucket_id
}

output "audit_bucket_arn" {
  description = "Dedicated CloudTrail audit bucket ARN."
  value       = module.security_audit.audit_bucket_arn
}

output "cloudtrail_name" {
  description = "Account audit CloudTrail trail name."
  value       = module.security_audit.cloudtrail_name
}

output "cloudtrail_arn" {
  description = "Account audit CloudTrail trail ARN."
  value       = module.security_audit.cloudtrail_arn
}

output "security_notification_topic_arn" {
  description = "Dedicated security notification SNS topic ARN."
  value       = module.security_audit.security_notification_topic_arn
}

output "security_event_rule_names" {
  description = "Security EventBridge rule names keyed by category."
  value       = module.security_audit.security_event_rule_names
}

output "security_event_rule_arns" {
  description = "Security EventBridge rule ARNs keyed by category."
  value       = module.security_audit.security_event_rule_arns
}

