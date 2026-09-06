output "audit_bucket_id" {
  description = "Dedicated CloudTrail audit bucket ID."
  value       = aws_s3_bucket.audit.id
}

output "audit_bucket_arn" {
  description = "Dedicated CloudTrail audit bucket ARN."
  value       = aws_s3_bucket.audit.arn
}

output "cloudtrail_name" {
  description = "Account audit CloudTrail trail name."
  value       = aws_cloudtrail.account_audit.name
}

output "cloudtrail_arn" {
  description = "Account audit CloudTrail trail ARN."
  value       = aws_cloudtrail.account_audit.arn
}

output "security_notification_topic_arn" {
  description = "Dedicated security notification SNS topic ARN."
  value       = aws_sns_topic.security_notifications.arn
}

output "security_event_rule_names" {
  description = "Security EventBridge rule names keyed by category."
  value = {
    root_activity            = aws_cloudwatch_event_rule.root_activity.name
    cloudtrail_tampering     = aws_cloudwatch_event_rule.cloudtrail_tampering.name
    iam_privilege_change     = aws_cloudwatch_event_rule.iam_privilege_change.name
    network_perimeter_change = aws_cloudwatch_event_rule.network_perimeter_change.name
    s3_security_change       = aws_cloudwatch_event_rule.s3_security_change.name
    console_login_no_mfa     = aws_cloudwatch_event_rule.console_login_without_mfa.name
  }
}

output "security_event_rule_arns" {
  description = "Security EventBridge rule ARNs keyed by category."
  value = {
    root_activity            = aws_cloudwatch_event_rule.root_activity.arn
    cloudtrail_tampering     = aws_cloudwatch_event_rule.cloudtrail_tampering.arn
    iam_privilege_change     = aws_cloudwatch_event_rule.iam_privilege_change.arn
    network_perimeter_change = aws_cloudwatch_event_rule.network_perimeter_change.arn
    s3_security_change       = aws_cloudwatch_event_rule.s3_security_change.arn
    console_login_no_mfa     = aws_cloudwatch_event_rule.console_login_without_mfa.arn
  }
}

