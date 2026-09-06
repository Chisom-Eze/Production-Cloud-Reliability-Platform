output "alb_arn" {
  description = "Application Load Balancer ARN."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Application Load Balancer hosted zone ID."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "API target group ARN."
  value       = aws_lb_target_group.api.arn
}

output "target_group_name" {
  description = "API target group name."
  value       = aws_lb_target_group.api.name
}

output "http_listener_arn" {
  description = "HTTP redirect listener ARN."
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "HTTPS listener ARN."
  value       = aws_lb_listener.https.arn
}

output "access_log_bucket_name" {
  description = "ALB access-log bucket name."
  value       = aws_s3_bucket.access_logs.bucket
}

output "access_log_bucket_arn" {
  description = "ALB access-log bucket ARN."
  value       = aws_s3_bucket.access_logs.arn
}
