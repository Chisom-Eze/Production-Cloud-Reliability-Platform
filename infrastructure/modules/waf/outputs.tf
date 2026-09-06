output "web_acl_id" {
  description = "WAFv2 Web ACL ID."
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_arn" {
  description = "WAFv2 Web ACL ARN."
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_name" {
  description = "WAFv2 Web ACL name."
  value       = aws_wafv2_web_acl.this.name
}

output "log_group_name" {
  description = "WAF CloudWatch log group name."
  value       = aws_cloudwatch_log_group.waf.name
}

output "log_group_arn" {
  description = "WAF CloudWatch log group ARN."
  value       = aws_cloudwatch_log_group.waf.arn
}
