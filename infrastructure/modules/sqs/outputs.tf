output "queue_id" {
  description = "Main SQS queue URL."
  value       = aws_sqs_queue.main.id
}

output "queue_url" {
  description = "Main SQS queue URL."
  value       = aws_sqs_queue.main.id
}

output "queue_arn" {
  description = "Main SQS queue ARN."
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "Main SQS queue name."
  value       = aws_sqs_queue.main.name
}

output "dlq_id" {
  description = "Dead-letter SQS queue URL."
  value       = aws_sqs_queue.dlq.id
}

output "dlq_url" {
  description = "Dead-letter SQS queue URL."
  value       = aws_sqs_queue.dlq.id
}

output "dlq_arn" {
  description = "Dead-letter SQS queue ARN."
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_name" {
  description = "Dead-letter SQS queue name."
  value       = aws_sqs_queue.dlq.name
}
