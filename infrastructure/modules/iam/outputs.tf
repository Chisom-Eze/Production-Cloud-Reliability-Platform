output "api_execution_role_arn" {
  description = "API ECS execution role ARN."
  value       = aws_iam_role.api_execution.arn
}

output "api_execution_role_name" {
  description = "API ECS execution role name."
  value       = aws_iam_role.api_execution.name
}

output "api_task_role_arn" {
  description = "API ECS task role ARN."
  value       = aws_iam_role.api_task.arn
}

output "api_task_role_name" {
  description = "API ECS task role name."
  value       = aws_iam_role.api_task.name
}

output "worker_execution_role_arn" {
  description = "Worker ECS execution role ARN."
  value       = aws_iam_role.worker_execution.arn
}

output "worker_execution_role_name" {
  description = "Worker ECS execution role name."
  value       = aws_iam_role.worker_execution.name
}

output "worker_task_role_arn" {
  description = "Worker ECS task role ARN."
  value       = aws_iam_role.worker_task.arn
}

output "worker_task_role_name" {
  description = "Worker ECS task role name."
  value       = aws_iam_role.worker_task.name
}
