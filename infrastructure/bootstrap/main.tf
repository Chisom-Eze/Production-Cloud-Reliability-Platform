data "aws_caller_identity" "current" {}

locals {
  standard_tags = {
    Owner       = "Chisom"
    Application = "ProductionCloudReliabilityPlatform"
    Environment = "shared"
    ManagedBy   = "Terraform"
  }

  github_oidc_host = replace(var.github_oidc_issuer_url, "https://", "")

  terraform_plan_state_keys = [
    "shared/container-registry/terraform.tfstate",
    "shared/security-audit/terraform.tfstate",
    "environments/development/terraform.tfstate"
  ]

  terraform_plan_lock_keys = [
    for state_key in local.terraform_plan_state_keys : "${state_key}.tflock"
  ]

  terraform_plan_state_object_arns = [
    for state_key in local.terraform_plan_state_keys : "${aws_s3_bucket.terraform_state.arn}/${state_key}"
  ]

  terraform_plan_lock_object_arns = [
    for state_key in local.terraform_plan_state_keys : "${aws_s3_bucket.terraform_state.arn}/${state_key}.tflock"
  ]

  bootstrap_state_object_arns = [
    "${aws_s3_bucket.terraform_state.arn}/bootstrap/terraform.tfstate",
    "${aws_s3_bucket.terraform_state.arn}/bootstrap/terraform.tfstate.tflock"
  ]

  project_s3_bucket_arns = [
    "arn:aws:s3:::production-cloud-reliability-audit-*",
    "arn:aws:s3:::prod-cloud-reliability-dev-artifacts-*",
    "arn:aws:s3:::prod-reliability-dev-alb-logs-*"
  ]

  project_iam_role_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/pcrp-GitHubDevelopmentDeployment",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/pcrp-GitHubDevelopmentTerraformPlan",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/pcrp-GitHubDevelopmentTerraformApply"
  ]

  project_iam_policy_arns = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/ProductionCloudReliabilityPlatformEcrPublish"
  ]
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

#trivy:ignore:AVD-AWS-0132 Artifact bucket uses the frozen SSE-S3/AES256 policy; no CMK requirement exists.
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
  name               = "pcrp-GitHubDevelopmentDeployment"
  description        = "Stage 2A GitHub Actions OIDC federation proof role. No broad deployment permissions yet."
  assume_role_policy = data.aws_iam_policy_document.github_development_assume_role.json
}

data "aws_iam_policy_document" "github_development_terraform_plan_assume_role" {
  statement {
    sid     = "AllowExactGitHubDevelopmentPlanEnvironment"
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
      values   = [var.github_development_plan_subject]
    }
  }
}

resource "aws_iam_role" "github_development_terraform_plan" {
  name                 = "pcrp-GitHubDevelopmentTerraformPlan"
  description          = "Read-only GitHub Actions role for authenticated Terraform plan in the development environment."
  assume_role_policy   = data.aws_iam_policy_document.github_development_terraform_plan_assume_role.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_development_terraform_plan_backend" {
  statement {
    sid     = "ListApprovedTerraformStatePrefixes"
    effect  = "Allow"
    actions = ["s3:ListBucket"]

    resources = [
      aws_s3_bucket.terraform_state.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = concat(local.terraform_plan_state_keys, local.terraform_plan_lock_keys)
    }
  }

  statement {
    sid     = "ReadApprovedTerraformState"
    effect  = "Allow"
    actions = ["s3:GetObject"]

    resources = local.terraform_plan_state_object_arns
  }

  statement {
    sid    = "AcquireAndReleaseApprovedTerraformLocks"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = local.terraform_plan_lock_object_arns
  }

  statement {
    sid    = "DenyBootstrapStateAccess"
    effect = "Deny"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = local.bootstrap_state_object_arns
  }

  statement {
    sid    = "DenyApprovedStateMutation"
    effect = "Deny"
    actions = [
      "s3:DeleteObject",
      "s3:PutObject"
    ]

    resources = local.terraform_plan_state_object_arns
  }
}

resource "aws_iam_role_policy" "github_development_terraform_plan_backend" {
  name   = "terraform-plan-backend-state-read-and-lock"
  role   = aws_iam_role.github_development_terraform_plan.id
  policy = data.aws_iam_policy_document.github_development_terraform_plan_backend.json
}

data "aws_iam_policy_document" "github_development_terraform_plan_read" {
  statement {
    sid    = "ReadEc2VpcAndEndpointConfiguration"
    effect = "Allow"
    actions = [
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribePrefixLists",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadLoadBalancerConfiguration"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadCertificateAndDnsConfiguration"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
      "route53:ListTagsForResources"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadDatabaseConfiguration"
    effect = "Allow"
    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeDBSubnetGroups",
      "rds:DescribePendingMaintenanceActions",
      "rds:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadQueueConfiguration"
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueueTags"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadProjectS3BucketConfiguration"
    effect = "Allow"
    actions = [
      "s3:GetAccelerateConfiguration",
      "s3:GetBucket*",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetObjectLockConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:ListBucket"
    ]
    resources = local.project_s3_bucket_arns
  }

  statement {
    sid    = "ReadProjectIamMetadata"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:ListRoleTags"
    ]
    resources = local.project_iam_role_arns
  }

  statement {
    sid    = "ReadProjectManagedPolicyMetadata"
    effect = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyTags",
      "iam:ListPolicyVersions"
    ]
    resources = local.project_iam_policy_arns
  }

  statement {
    sid    = "ReadEcsConfiguration"
    effect = "Allow"
    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadApplicationAutoScalingConfiguration"
    effect = "Allow"
    actions = [
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:DescribeScalingActivities",
      "application-autoscaling:DescribeScalingPolicies"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadCloudWatchAndLogsConfiguration"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetDashboard",
      "cloudwatch:ListDashboards",
      "cloudwatch:ListTagsForResource",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:DescribeQueryDefinitions",
      "logs:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadWafConfiguration"
    effect = "Allow"
    actions = [
      "wafv2:GetLoggingConfiguration",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:ListResourcesForWebACL",
      "wafv2:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadEcrConfiguration"
    effect = "Allow"
    actions = [
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadSecurityAuditConfiguration"
    effect = "Allow"
    actions = [
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetEventSelectors",
      "cloudtrail:GetInsightSelectors",
      "cloudtrail:GetTrail",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:ListTags",
      "events:DescribeRule",
      "events:ListTagsForResource",
      "events:ListTargetsByRule",
      "sns:GetTopicAttributes",
      "sns:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadManagedObservabilityConfiguration"
    effect = "Allow"
    actions = [
      "aps:DescribeWorkspace",
      "aps:ListTagsForResource",
      "grafana:DescribeWorkspace",
      "grafana:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadSecretMetadataOnly"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyIamMutationAndPassRole"
    effect = "Deny"
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:AttachRolePolicy",
      "iam:CreateAccessKey",
      "iam:CreateInstanceProfile",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:DeleteOpenIDConnectProvider",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRole",
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:TagRole",
      "iam:UntagPolicy",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyEcrPublishingAndRepositoryMutation"
    effect = "Deny"
    actions = [
      "ecr:BatchDeleteImage",
      "ecr:CompleteLayerUpload",
      "ecr:DeleteLifecyclePolicy",
      "ecr:DeleteRepository",
      "ecr:DeleteRepositoryPolicy",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:PutLifecyclePolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:UploadLayerPart"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyEcsReleaseMutation"
    effect = "Deny"
    actions = [
      "ecs:CreateCluster",
      "ecs:CreateService",
      "ecs:DeleteCluster",
      "ecs:DeleteService",
      "ecs:DeregisterTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:UpdateService"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_development_terraform_plan_read" {
  name   = "terraform-plan-aws-read-only"
  role   = aws_iam_role.github_development_terraform_plan.id
  policy = data.aws_iam_policy_document.github_development_terraform_plan_read.json
}
