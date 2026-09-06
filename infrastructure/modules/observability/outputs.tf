output "workspace_id" {
  description = "AMP workspace ID."
  value       = aws_prometheus_workspace.this.id
}

output "workspace_arn" {
  description = "AMP workspace ARN."
  value       = aws_prometheus_workspace.this.arn
}

output "workspace_prometheus_endpoint" {
  description = "AMP Prometheus endpoint."
  value       = aws_prometheus_workspace.this.prometheus_endpoint
}

output "grafana_workspace_id" {
  description = "Amazon Managed Grafana workspace ID."
  value       = aws_grafana_workspace.this.id
}

output "grafana_workspace_arn" {
  description = "Amazon Managed Grafana workspace ARN."
  value       = aws_grafana_workspace.this.arn
}

output "grafana_endpoint" {
  description = "Amazon Managed Grafana workspace endpoint."
  value       = aws_grafana_workspace.this.endpoint
}

output "alarm_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications."
  value       = aws_sns_topic.alarms.arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}
