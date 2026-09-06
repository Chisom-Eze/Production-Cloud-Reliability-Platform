output "api_scalable_target_resource_id" {
  description = "API scalable target resource ID."
  value       = aws_appautoscaling_target.api.resource_id
}

output "api_scalable_target_min_capacity" {
  description = "API scalable target minimum capacity."
  value       = aws_appautoscaling_target.api.min_capacity
}

output "api_scalable_target_max_capacity" {
  description = "API scalable target maximum capacity."
  value       = aws_appautoscaling_target.api.max_capacity
}

output "worker_scalable_target_resource_id" {
  description = "Worker scalable target resource ID."
  value       = aws_appautoscaling_target.worker.resource_id
}

output "worker_scalable_target_min_capacity" {
  description = "Worker scalable target minimum capacity."
  value       = aws_appautoscaling_target.worker.min_capacity
}

output "worker_scalable_target_max_capacity" {
  description = "Worker scalable target maximum capacity."
  value       = aws_appautoscaling_target.worker.max_capacity
}

output "api_cpu_policy_name" {
  description = "API CPU target-tracking policy name."
  value       = aws_appautoscaling_policy.api_cpu.name
}

output "api_cpu_policy_arn" {
  description = "API CPU target-tracking policy ARN."
  value       = aws_appautoscaling_policy.api_cpu.arn
}

output "api_memory_policy_name" {
  description = "API memory target-tracking policy name."
  value       = aws_appautoscaling_policy.api_memory.name
}

output "api_memory_policy_arn" {
  description = "API memory target-tracking policy ARN."
  value       = aws_appautoscaling_policy.api_memory.arn
}

output "worker_backlog_policy_name" {
  description = "Worker backlog-per-task target-tracking policy name."
  value       = aws_appautoscaling_policy.worker_backlog.name
}

output "worker_backlog_policy_arn" {
  description = "Worker backlog-per-task target-tracking policy ARN."
  value       = aws_appautoscaling_policy.worker_backlog.arn
}
