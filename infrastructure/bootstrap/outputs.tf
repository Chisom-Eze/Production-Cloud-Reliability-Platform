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

