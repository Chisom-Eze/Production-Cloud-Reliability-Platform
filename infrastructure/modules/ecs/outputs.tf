output "cluster_id" {
  description = "ECS cluster ID."
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "api_task_definition_arn" {
  description = "API task definition ARN."
  value       = aws_ecs_task_definition.api.arn
}

output "api_task_definition_family" {
  description = "API task definition family."
  value       = aws_ecs_task_definition.api.family
}

output "api_service_name" {
  description = "API ECS service name."
  value       = aws_ecs_service.api.name
}

output "api_service_id" {
  description = "API ECS service ID."
  value       = aws_ecs_service.api.id
}

output "worker_task_definition_arn" {
  description = "Worker task definition ARN."
  value       = aws_ecs_task_definition.worker.arn
}

output "worker_task_definition_family" {
  description = "Worker task definition family."
  value       = aws_ecs_task_definition.worker.family
}

output "worker_service_name" {
  description = "Worker ECS service name."
  value       = aws_ecs_service.worker.name
}

output "worker_service_id" {
  description = "Worker ECS service ID."
  value       = aws_ecs_service.worker.id
}

output "migration_task_definition_arn" {
  description = "Migration task definition ARN."
  value       = aws_ecs_task_definition.migration.arn
}

output "migration_task_definition_family" {
  description = "Migration task definition family."
  value       = aws_ecs_task_definition.migration.family
}

output "api_log_group_name" {
  description = "API CloudWatch log group name."
  value       = aws_cloudwatch_log_group.api.name
}

output "api_log_group_arn" {
  description = "API CloudWatch log group ARN."
  value       = aws_cloudwatch_log_group.api.arn
}

output "nginx_log_group_name" {
  description = "Nginx CloudWatch log group name."
  value       = aws_cloudwatch_log_group.nginx.name
}

output "nginx_log_group_arn" {
  description = "Nginx CloudWatch log group ARN."
  value       = aws_cloudwatch_log_group.nginx.arn
}

output "worker_log_group_name" {
  description = "Worker CloudWatch log group name."
  value       = aws_cloudwatch_log_group.worker.name
}

output "worker_log_group_arn" {
  description = "Worker CloudWatch log group ARN."
  value       = aws_cloudwatch_log_group.worker.arn
}
