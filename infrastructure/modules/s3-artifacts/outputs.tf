output "bucket_id" {
  description = "Artifact S3 bucket ID."
  value       = aws_s3_bucket.this.id
}

output "bucket_name" {
  description = "Artifact S3 bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "Artifact S3 bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "Artifact S3 bucket regional domain name."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
