output "aws_account_id" {
  description = "AWS account ID discovered from the active caller identity."
  value       = data.aws_caller_identity.current.account_id
}

output "state_bucket_name" {
  description = "Terraform state S3 bucket name."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "Terraform state S3 bucket ARN."
  value       = aws_s3_bucket.terraform_state.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_development_deployment_role_arn" {
  description = "GitHub development deployment role ARN."
  value       = aws_iam_role.github_development_deployment.arn
}

output "github_development_terraform_plan_role_name" {
  description = "GitHub development Terraform plan role name."
  value       = aws_iam_role.github_development_terraform_plan.name
}

output "github_development_terraform_plan_role_arn" {
  description = "GitHub development Terraform plan role ARN."
  value       = aws_iam_role.github_development_terraform_plan.arn
}

output "github_development_terraform_apply_role_name" {
  description = "GitHub development Terraform apply role name."
  value       = aws_iam_role.github_development_terraform_apply.name
}

output "github_development_terraform_apply_role_arn" {
  description = "GitHub development Terraform apply role ARN."
  value       = aws_iam_role.github_development_terraform_apply.arn
}

output "github_development_ecr_publisher_role_name" {
  description = "GitHub development ECR publisher role name."
  value       = aws_iam_role.github_development_ecr_publisher.name
}

output "github_development_ecr_publisher_role_arn" {
  description = "GitHub development ECR publisher role ARN."
  value       = aws_iam_role.github_development_ecr_publisher.arn
}

output "github_development_ecs_release_role_name" {
  description = "GitHub development ECS release role name."
  value       = aws_iam_role.github_development_ecs_release.name
}

output "github_development_ecs_release_role_arn" {
  description = "GitHub development ECS release role ARN."
  value       = aws_iam_role.github_development_ecs_release.arn
}
