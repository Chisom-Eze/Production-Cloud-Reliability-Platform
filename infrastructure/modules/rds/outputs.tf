output "identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.identifier
}

output "arn" {
  description = "RDS instance ARN."
  value       = aws_db_instance.this.arn
}

output "address" {
  description = "RDS instance DNS address."
  value       = aws_db_instance.this.address
}

output "endpoint" {
  description = "RDS instance endpoint including port."
  value       = aws_db_instance.this.endpoint
}

output "port" {
  description = "RDS listener port."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.this.db_name
}

output "db_subnet_group_name" {
  description = "RDS DB subnet group name."
  value       = aws_db_subnet_group.this.name
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN for the RDS-managed master user secret."
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
  sensitive   = true
}

output "enhanced_monitoring_role_arn" {
  description = "Enhanced Monitoring IAM role ARN, when enabled."
  value       = try(aws_iam_role.enhanced_monitoring[0].arn, null)
}
