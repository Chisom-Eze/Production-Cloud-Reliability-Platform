data "aws_caller_identity" "current" {}

locals {
  standard_tags = {
    Owner       = "Chisom"
    Application = "ProductionCloudReliabilityPlatform"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }

  github_oidc_host = replace(var.github_oidc_issuer_url, "https://", "")
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Accepted risk: SSE-S3 is intentionally retained for this project for
# cost and operational simplicity. State remains encrypted, private,
# versioned and IAM-controlled.
#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "terraform-state-version-retention"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state_tls_only" {
  bucket = aws_s3_bucket.terraform_state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = var.github_oidc_issuer_url

  client_id_list = [
    var.github_oidc_audience
  ]
}

data "aws_iam_policy_document" "github_development_assume_role" {
  statement {
    sid     = "AllowExactGitHubDevelopmentEnvironment"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:aud"
      values   = [var.github_oidc_audience]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_host}:sub"
      values   = [var.github_development_subject]
    }
  }
}

resource "aws_iam_role" "github_development_deployment" {
  name               = "ProductionCloudReliabilityPlatform-GitHubDevelopmentDeployment"
  description        = "Stage 2A GitHub Actions OIDC federation proof role. No broad deployment permissions yet."
  assume_role_policy = data.aws_iam_policy_document.github_development_assume_role.json
}
