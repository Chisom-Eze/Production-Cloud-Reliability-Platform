output "alb_security_group_id" {
  description = "ALB security group ID."
  value       = aws_security_group.alb.id
}

output "api_security_group_id" {
  description = "API ECS task security group ID."
  value       = aws_security_group.api.id
}

output "worker_security_group_id" {
  description = "Worker ECS task security group ID."
  value       = aws_security_group.worker.id
}

output "rds_security_group_id" {
  description = "RDS PostgreSQL security group ID."
  value       = aws_security_group.rds.id
}
