output "aws_account_id" {
  description = "AWS account ID discovered from the active caller identity."
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_repository_names" {
  description = "ECR repository names keyed by application component."
  value = {
    for component, repository in module.ecr : component => repository.repository_name
  }
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by application component."
  value = {
    for component, repository in module.ecr : component => repository.repository_url
  }
}

output "ecr_repository_arns" {
  description = "ECR repository ARNs keyed by application component."
  value = {
    for component, repository in module.ecr : component => repository.repository_arn
  }
}

output "github_development_ecr_publish_policy_arn" {
  description = "Customer-managed ECR publishing policy attached to the existing GitHub development deployment role."
  value       = aws_iam_policy.github_development_ecr_publish.arn
}
