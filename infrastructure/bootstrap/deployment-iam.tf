locals {
  github_development_deployment_role_name      = "ProductionCloudReliabilityPlatform-GitHubDevelopmentDeployment"
  github_development_terraform_plan_role_name  = "pcrp-GitHubDevelopmentTerraformPlan"
  github_development_terraform_apply_role_name = "pcrp-GitHubDevelopmentTerraformApply"
  github_development_ecr_publisher_role_name   = "pcrp-GitHubDevelopmentEcrPublisher"
  github_development_ecs_release_role_name     = "pcrp-GitHubDevelopmentEcsRelease"

  github_development_deployment_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.github_development_deployment_role_name}"
  github_development_terraform_plan_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.github_development_terraform_plan_role_name}"
  github_development_terraform_apply_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.github_development_terraform_apply_role_name}"
  github_development_ecr_publisher_role_arn   = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.github_development_ecr_publisher_role_name}"
  github_development_ecs_release_role_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.github_development_ecs_release_role_name}"

  github_project_role_arns = [
    local.github_development_deployment_role_arn,
    local.github_development_terraform_plan_role_arn,
    local.github_development_terraform_apply_role_arn,
    local.github_development_ecr_publisher_role_arn,
    local.github_development_ecs_release_role_arn
  ]

  development_environment       = "development"
  development_project_name      = "production-cloud-reliability-platform"
  development_project_slug      = "prod-cloud-reliability"
  development_edge_project_slug = "prod-reliability"
  development_name_prefix       = "${local.development_project_name}-${local.development_environment}"
  development_workload_prefix   = "${local.development_project_slug}-${local.development_environment}"

  development_api_execution_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.development_workload_prefix}-api-execution"
  development_api_task_role_arn         = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.development_workload_prefix}-api-task"
  development_worker_execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.development_workload_prefix}-worker-execution"
  development_worker_task_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.development_workload_prefix}-worker-task"

  development_rds_enhanced_monitoring_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.development_name_prefix}-postgres-em"
  development_grafana_role_arn                 = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.development_name_prefix}-grafana"

  development_workload_role_arns = [
    local.development_api_execution_role_arn,
    local.development_api_task_role_arn,
    local.development_worker_execution_role_arn,
    local.development_worker_task_role_arn
  ]

  development_owned_iam_role_arns = concat(
    local.development_workload_role_arns,
    [
      local.development_rds_enhanced_monitoring_role_arn,
      local.development_grafana_role_arn
    ]
  )

  ecr_publish_policy_name = "ProductionCloudReliabilityPlatformEcrPublish"
  ecr_publish_policy_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.ecr_publish_policy_name}"

  ecs_release_runtime_policy_name = "pcrp-GitHubDevelopmentEcsReleaseRuntime"
  ecs_release_runtime_policy_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.ecs_release_runtime_policy_name}"

  project_ecr_repository_arns = [
    "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/production-cloud-reliability-api",
    "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/production-cloud-reliability-nginx",
    "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/production-cloud-reliability-worker"
  ]

  development_ecs_cluster_arn = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${local.development_name_prefix}"

  development_ecs_service_arns = [
    "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${local.development_name_prefix}/${local.development_name_prefix}-api",
    "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${local.development_name_prefix}/${local.development_name_prefix}-worker"
  ]

  development_ecs_task_definition_arns = [
    "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.development_name_prefix}-api:*",
    "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.development_name_prefix}-worker:*",
    "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.development_name_prefix}-migration:*"
  ]

  development_ec2_resource_arns = [
    "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:elastic-ip/*",
    "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:internet-gateway/*",
    "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:natgateway/*",
    "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:network-interface/*",
    "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:route-table/*",
    "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/*",
    "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group-rule/*",
    "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subnet/*",
    "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc/*",
    "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc-endpoint/*"
  ]

  development_alb_arn = "arn:aws:elasticloadbalancing:${var.aws_region}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/${local.development_edge_project_slug}-${local.development_environment}-alb/*"

  development_elbv2_resource_arns = [
    local.development_alb_arn,
    "arn:aws:elasticloadbalancing:${var.aws_region}:${data.aws_caller_identity.current.account_id}:listener/app/${local.development_edge_project_slug}-${local.development_environment}-alb/*/*",
    "arn:aws:elasticloadbalancing:${var.aws_region}:${data.aws_caller_identity.current.account_id}:targetgroup/${local.development_edge_project_slug}-${local.development_environment}-api/*"
  ]

  development_acm_certificate_arns = [
    "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/*"
  ]

  development_waf_web_acl_arn = "arn:aws:wafv2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:regional/webacl/${local.development_edge_project_slug}-${local.development_environment}-web-acl/*"

  development_rds_resource_arns = [
    "arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:db:${local.development_name_prefix}-postgres",
    "arn:aws:rds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:subgrp:${local.development_name_prefix}-db-subnets"
  ]

  development_rds_managed_secret_arns = [
    "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:rds!db-*"
  ]

  project_logs_resource_arns = [
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/production-cloud-reliability/${local.development_environment}/api",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/production-cloud-reliability/${local.development_environment}/api:*",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/production-cloud-reliability/${local.development_environment}/nginx",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/production-cloud-reliability/${local.development_environment}/nginx:*",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/production-cloud-reliability/${local.development_environment}/worker",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/production-cloud-reliability/${local.development_environment}/worker:*",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/rds/instance/${local.development_name_prefix}-postgres/*",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/rds/instance/${local.development_name_prefix}-postgres/*:*",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${local.development_edge_project_slug}-${local.development_environment}",
    "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${local.development_edge_project_slug}-${local.development_environment}:*"
  ]

  project_cloudtrail_arn = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${local.development_project_name}-account-audit"

  project_eventbridge_rule_arns = [
    "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${local.development_project_name}-root-activity-critical",
    "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/pcrp-cloudtrail-tampering-critical",
    "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/pcrp-iam-privilege-change-warning",
    "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/pcrp-network-perimeter-change-warning",
    "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${local.development_project_name}-s3-security-change-warning",
    "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/pcrp-console-login-without-mfa-warning"
  ]

  project_sns_topic_arns = [
    "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${local.development_project_name}-security-notifications",
    "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${local.development_name_prefix}-alarms"
  ]

  project_sqs_queue_arns = [
    "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:ProductionCloudReliabilityPlatform-${local.development_environment}-jobs",
    "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:ProductionCloudReliabilityPlatform-${local.development_environment}-jobs-dlq"
  ]

  project_amp_workspace_arns = [
    "arn:aws:aps:${var.aws_region}:${data.aws_caller_identity.current.account_id}:workspace/*"
  ]

  project_grafana_workspace_arns = [
    "arn:aws:grafana:${var.aws_region}:${data.aws_caller_identity.current.account_id}:/workspaces/*"
  ]

  project_cloudwatch_alarm_arns = [
    "arn:aws:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${local.development_name_prefix}-*"
  ]

  project_cloudwatch_dashboard_arns = [
    "arn:aws:cloudwatch::${data.aws_caller_identity.current.account_id}:dashboard/${local.development_name_prefix}-operations"
  ]

  project_application_autoscaling_target_arns = [
    "arn:aws:application-autoscaling:${var.aws_region}:${data.aws_caller_identity.current.account_id}:scalable-target/*"
  ]
}

data "aws_iam_policy_document" "github_development_terraform_apply_assume_role" {
  statement {
    sid     = "AllowExactGitHubDevelopmentApplyEnvironment"
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
      values   = [var.github_development_apply_subject]
    }
  }
}

data "aws_iam_policy_document" "github_development_ecr_publisher_assume_role" {
  statement {
    sid     = "AllowExactGitHubDevelopmentPublishEnvironment"
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
      values   = [var.github_development_publish_subject]
    }
  }
}

data "aws_iam_policy_document" "github_development_ecs_release_assume_role" {
  statement {
    sid     = "AllowExactGitHubDevelopmentReleaseEnvironment"
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
      values   = [var.github_development_release_subject]
    }
  }
}

resource "aws_iam_role" "github_development_terraform_apply" {
  name                 = local.github_development_terraform_apply_role_name
  description          = "GitHub Actions role for Terraform apply in the development environment, excluding bootstrap state."
  assume_role_policy   = data.aws_iam_policy_document.github_development_terraform_apply_assume_role.json
  max_session_duration = 3600
}

resource "aws_iam_role" "github_development_ecr_publisher" {
  name                 = local.github_development_ecr_publisher_role_name
  description          = "GitHub Actions role for publishing development container images to project ECR repositories."
  assume_role_policy   = data.aws_iam_policy_document.github_development_ecr_publisher_assume_role.json
  max_session_duration = 3600
}

resource "aws_iam_role" "github_development_ecs_release" {
  name                 = local.github_development_ecs_release_role_name
  description          = "GitHub Actions role for migration execution and ECS service promotion in development."
  assume_role_policy   = data.aws_iam_policy_document.github_development_ecs_release_assume_role.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_development_terraform_apply_backend" {
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
    sid    = "ReadWriteApprovedTerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

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
    sid       = "DenyApprovedTerraformStateDeletion"
    effect    = "Deny"
    actions   = ["s3:DeleteObject"]
    resources = local.terraform_plan_state_object_arns
  }
}

resource "aws_iam_policy" "github_development_terraform_apply_backend" {
  name        = "pcrp-GitHubDevelopmentTerraformApplyBackend"
  description = "Terraform Apply access to approved non-bootstrap S3 state and native lockfiles."
  policy      = data.aws_iam_policy_document.github_development_terraform_apply_backend.json
}

resource "aws_iam_role_policy_attachment" "github_development_terraform_apply_backend" {
  role       = aws_iam_role.github_development_terraform_apply.name
  policy_arn = aws_iam_policy.github_development_terraform_apply_backend.arn
}

data "aws_iam_policy_document" "github_development_terraform_apply_network" {
  statement {
    sid    = "ReadProviderAndNetworkMetadata"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity",
      "ec2:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadVpcSecurityGroups"
    effect    = "Allow"
    actions   = ["ec2:GetSecurityGroupsForVpc"]
    resources = ["arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc/*"]
  }

  statement {
    sid    = "ManageDevelopmentVpcAndRoutes"
    effect = "Allow"
    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:CreateInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteNatGateway",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVpc",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateRouteTable",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:ReleaseAddress",
      "ec2:ReplaceRoute",
      "ec2:ReplaceRouteTableAssociation"
    ]
    resources = local.development_ec2_resource_arns
  }

  statement {
    sid    = "ManageDevelopmentSecurityGroups"
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:ModifySecurityGroupRules",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress"
    ]
    resources = local.development_ec2_resource_arns
  }

  statement {
    sid    = "ManageDevelopmentVpcEndpoints"
    effect = "Allow"
    actions = [
      "ec2:CreateVpcEndpoint",
      "ec2:DeleteVpcEndpoints",
      "ec2:ModifyVpcEndpoint"
    ]
    resources = local.development_ec2_resource_arns
  }
}

resource "aws_iam_policy" "github_development_terraform_apply_network" {
  name        = "pcrp-GitHubDevelopmentTerraformApplyNetwork"
  description = "Terraform Apply VPC, subnet, routing, security-group, and endpoint permissions for approved roots."
  policy      = data.aws_iam_policy_document.github_development_terraform_apply_network.json

  lifecycle {
    precondition {
      condition     = length(data.aws_iam_policy_document.github_development_terraform_apply_network.json) <= 6144
      error_message = "Terraform Apply Network policy JSON exceeds the 6144-character IAM managed-policy limit."
    }
  }
}

resource "aws_iam_role_policy_attachment" "github_development_terraform_apply_network" {
  role       = aws_iam_role.github_development_terraform_apply.name
  policy_arn = aws_iam_policy.github_development_terraform_apply_network.arn
}

data "aws_iam_policy_document" "github_development_terraform_apply_edge" {
  statement {
    sid    = "ReadEdgeMetadata"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DescribeWebACLAssociation",
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:ListTagsForCertificate",
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
      "route53:ListTagsForResources",
      "wafv2:CheckCapacity",
      "wafv2:ListWebACLs"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadDevelopmentWafWebAcl"
    effect = "Allow"
    actions = [
      "wafv2:GetLoggingConfiguration",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:ListResourcesForWebACL",
      "wafv2:ListTagsForResource"
    ]
    resources = [local.development_waf_web_acl_arn]
  }

  statement {
    sid       = "ReadDevelopmentAlbWebAcl"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:GetLoadBalancerWebACL"]
    resources = [local.development_alb_arn]
  }

  statement {
    sid    = "ManageDevelopmentLoadBalancing"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets"
    ]
    resources = local.development_elbv2_resource_arns
  }

  statement {
    sid    = "ManageDevelopmentCertificates"
    effect = "Allow"
    actions = [
      "acm:AddTagsToCertificate",
      "acm:DeleteCertificate",
      "acm:RemoveTagsFromCertificate",
      "acm:RequestCertificate"
    ]
    resources = local.development_acm_certificate_arns
  }

  statement {
    sid       = "CreateSharedPublicHostedZone"
    effect    = "Allow"
    actions   = ["route53:CreateHostedZone"]
    resources = ["*"]
  }

  statement {
    sid    = "ManageSharedPublicHostedZoneLifecycle"
    effect = "Allow"
    actions = [
      "route53:ChangeTagsForResource",
      "route53:DeleteHostedZone",
      "route53:UpdateHostedZoneComment"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/*"
    ]
  }

  statement {
    sid    = "ManageDevelopmentDnsRecords"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/*"
    ]
  }

  statement {
    sid    = "ManageDevelopmentWaf"
    effect = "Allow"
    actions = [
      "wafv2:DeleteLoggingConfiguration",
      "wafv2:DeleteWebACL",
      "wafv2:PutLoggingConfiguration",
      "wafv2:TagResource",
      "wafv2:UntagResource"
    ]
    resources = [local.development_waf_web_acl_arn]
  }

  statement {
    sid    = "CreateAndUpdateDevelopmentWafWithManagedRules"
    effect = "Allow"
    actions = [
      "wafv2:CreateWebACL",
      "wafv2:UpdateWebACL"
    ]
    resources = [
      local.development_waf_web_acl_arn,
      "arn:aws:wafv2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:regional/managedruleset/*/*"
    ]
  }

  statement {
    sid       = "AssociateDevelopmentWafWebAcl"
    effect    = "Allow"
    actions   = ["wafv2:AssociateWebACL"]
    resources = [local.development_waf_web_acl_arn]
  }

  statement {
    sid       = "AssociateDevelopmentAlbWebAcl"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:CreateWebACLAssociation"]
    resources = [local.development_alb_arn]
  }

  statement {
    sid       = "DisassociateDevelopmentWafWebAcl"
    effect    = "Allow"
    actions   = ["wafv2:DisassociateWebACL"]
    resources = ["*"]
  }

  statement {
    sid       = "DisassociateDevelopmentAlbWebAcl"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:DeleteWebACLAssociation"]
    resources = [local.development_alb_arn]
  }
}

resource "aws_iam_policy" "github_development_terraform_apply_edge" {
  name        = "pcrp-GitHubDevelopmentTerraformApplyEdge"
  description = "Terraform Apply ALB, certificate, DNS, and WAF permissions for approved roots."
  policy      = data.aws_iam_policy_document.github_development_terraform_apply_edge.json

  lifecycle {
    precondition {
      condition     = length(data.aws_iam_policy_document.github_development_terraform_apply_edge.json) <= 6144
      error_message = "Terraform Apply Edge policy JSON exceeds the 6144-character IAM managed-policy limit."
    }
  }
}

resource "aws_iam_role_policy_attachment" "github_development_terraform_apply_edge" {
  role       = aws_iam_role.github_development_terraform_apply.name
  policy_arn = aws_iam_policy.github_development_terraform_apply_edge.arn
}

data "aws_iam_policy_document" "github_development_terraform_apply_data" {
  statement {
    sid    = "ReadDataConfiguration"
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
    sid    = "ReadProjectQueueConfiguration"
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListDeadLetterSourceQueues",
      "sqs:ListQueueTags"
    ]
    resources = local.project_sqs_queue_arns
  }

  statement {
    sid    = "ListDataPlaneResources"
    effect = "Allow"
    actions = [
      "s3:ListAllMyBuckets",
      "sqs:ListQueues"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageProjectS3Buckets"
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketEncryption",
      "s3:DeleteBucketOwnershipControls",
      "s3:DeleteBucketPolicy",
      "s3:DeleteBucketTagging",
      "s3:DeleteLifecycleConfiguration",
      "s3:DeletePublicAccessBlock",
      "s3:PutBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketOwnershipControls"
    ]
    resources = local.project_s3_bucket_arns
  }

  statement {
    sid    = "ManageDatabase"
    effect = "Allow"
    actions = [
      "rds:AddTagsToResource",
      "rds:CreateDBInstance",
      "rds:CreateDBSubnetGroup",
      "rds:DeleteDBInstance",
      "rds:DeleteDBSubnetGroup",
      "rds:ModifyDBInstance",
      "rds:ModifyDBSubnetGroup",
      "rds:RemoveTagsFromResource"
    ]
    resources = local.development_rds_resource_arns
  }

  statement {
    sid    = "ReadGeneratedDatabaseSecretMetadata"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = local.development_rds_managed_secret_arns
  }

  statement {
    sid    = "CreateRdsManagedDatabaseSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:TagResource"
    ]
    resources = local.development_rds_managed_secret_arns
  }

  statement {
    sid       = "DescribeRdsManagedSecretKey"
    effect    = "Allow"
    actions   = ["kms:DescribeKey"]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "kms:ResourceAliases"
      values   = ["alias/aws/secretsmanager"]
    }
  }

  statement {
    sid    = "CreateProjectQueues"
    effect = "Allow"
    actions = [
      "sqs:CreateQueue"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageProjectQueues"
    effect = "Allow"
    actions = [
      "sqs:DeleteQueue",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
      "sqs:UntagQueue"
    ]
    resources = local.project_sqs_queue_arns
  }
}

resource "aws_iam_policy" "github_development_terraform_apply_data" {
  name        = "pcrp-GitHubDevelopmentTerraformApplyData"
  description = "Terraform Apply S3, RDS, generated-secret metadata, and SQS infrastructure permissions."
  policy      = data.aws_iam_policy_document.github_development_terraform_apply_data.json

  lifecycle {
    precondition {
      condition     = length(data.aws_iam_policy_document.github_development_terraform_apply_data.json) <= 6144
      error_message = "Terraform Apply Data policy JSON exceeds the 6144-character IAM managed-policy limit."
    }
  }
}

resource "aws_iam_role_policy_attachment" "github_development_terraform_apply_data" {
  role       = aws_iam_role.github_development_terraform_apply.name
  policy_arn = aws_iam_policy.github_development_terraform_apply_data.arn
}

data "aws_iam_policy_document" "github_development_terraform_apply_runtime" {
  statement {
    sid    = "ReadRuntimeConfiguration"
    effect = "Allow"
    actions = [
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:DescribeScalingActivities",
      "application-autoscaling:DescribeScalingPolicies",
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadProjectEcrConfiguration"
    effect = "Allow"
    actions = [
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetLifecyclePolicy",
      "ecr:ListTagsForResource"
    ]
    resources = local.project_ecr_repository_arns
  }

  statement {
    sid    = "ManageEcsClusterServicesAndTaskDefinitions"
    effect = "Allow"
    actions = [
      "ecs:CreateCluster",
      "ecs:CreateService",
      "ecs:DeleteCluster",
      "ecs:DeleteService",
      "ecs:DeregisterTaskDefinition",
      "ecs:TagResource",
      "ecs:UntagResource",
      "ecs:UpdateClusterSettings",
      "ecs:UpdateService"
    ]
    resources = concat(
      [local.development_ecs_cluster_arn],
      local.development_ecs_service_arns,
      local.development_ecs_task_definition_arns
    )
  }

  statement {
    sid       = "RegisterTerraformOwnedTaskDefinitions"
    effect    = "Allow"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid    = "ManageApplicationAutoScaling"
    effect = "Allow"
    actions = [
      "application-autoscaling:DeleteScalingPolicy",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:TagResource",
      "application-autoscaling:UntagResource"
    ]
    resources = local.project_application_autoscaling_target_arns
  }

  statement {
    sid    = "ManageEcrRepositoryInfrastructure"
    effect = "Allow"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteLifecyclePolicy",
      "ecr:DeleteRepository",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:PutLifecyclePolicy",
      "ecr:TagResource",
      "ecr:UntagResource"
    ]
    resources = local.project_ecr_repository_arns
  }

  statement {
    sid    = "DenyEcrImagePublishing"
    effect = "Deny"
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = local.project_ecr_repository_arns
  }

  statement {
    sid       = "DenyMigrationTaskExecution"
    effect    = "Deny"
    actions   = ["ecs:RunTask"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_development_terraform_apply_runtime" {
  name        = "pcrp-GitHubDevelopmentTerraformApplyRuntime"
  description = "Terraform Apply ECS, task-definition, autoscaling, and ECR infrastructure permissions."
  policy      = data.aws_iam_policy_document.github_development_terraform_apply_runtime.json

  lifecycle {
    precondition {
      condition     = length(data.aws_iam_policy_document.github_development_terraform_apply_runtime.json) <= 6144
      error_message = "Terraform Apply Runtime policy JSON exceeds the 6144-character IAM managed-policy limit."
    }
  }
}

resource "aws_iam_role_policy_attachment" "github_development_terraform_apply_runtime" {
  role       = aws_iam_role.github_development_terraform_apply.name
  policy_arn = aws_iam_policy.github_development_terraform_apply_runtime.arn
}

data "aws_iam_policy_document" "github_development_terraform_apply_observability_audit" {
  statement {
    sid    = "ReadObservabilityAndAuditMetadata"
    effect = "Allow"
    actions = [
      "aps:DescribeWorkspace",
      "aps:ListTagsForResource",
      "aps:ListWorkspaces",
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetEventSelectors",
      "cloudtrail:GetInsightSelectors",
      "cloudtrail:GetTrail",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:ListTags",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetDashboard",
      "cloudwatch:ListDashboards",
      "cloudwatch:ListTagsForResource",
      "events:DescribeRule",
      "events:ListTagsForResource",
      "events:ListTargetsByRule",
      "grafana:DescribeWorkspace",
      "grafana:ListTagsForResource",
      "grafana:ListWorkspaces",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:DescribeQueryDefinitions",
      "logs:ListTagsForResource",
      "sns:GetTopicAttributes",
      "sns:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageProjectCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DeleteRetentionPolicy",
      "logs:PutRetentionPolicy",
      "logs:TagLogGroup",
      "logs:TagResource",
      "logs:UntagLogGroup",
      "logs:UntagResource"
    ]
    resources = local.project_logs_resource_arns
  }

  statement {
    sid    = "ManageWafLogDeliveryControlPlane"
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:DescribeResourcePolicies",
      "logs:GetLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:UpdateLogDelivery"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageProjectCloudWatchAlarmsDashboardsAndQueries"
    effect = "Allow"
    actions = [
      "logs:DeleteQueryDefinition",
      "logs:PutQueryDefinition"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ManageProjectCloudWatchAlarms"
    effect = "Allow"
    actions = [
      "cloudwatch:DeleteAlarms",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource"
    ]
    resources = local.project_cloudwatch_alarm_arns
  }

  statement {
    sid    = "ManageProjectCloudWatchDashboard"
    effect = "Allow"
    actions = [
      "cloudwatch:DeleteDashboards",
      "cloudwatch:PutDashboard"
    ]
    resources = local.project_cloudwatch_dashboard_arns
  }

  statement {
    sid    = "ManageSecurityAuditTrail"
    effect = "Allow"
    actions = [
      "cloudtrail:AddTags",
      "cloudtrail:CreateTrail",
      "cloudtrail:DeleteTrail",
      "cloudtrail:PutEventSelectors",
      "cloudtrail:RemoveTags",
      "cloudtrail:StartLogging",
      "cloudtrail:StopLogging",
      "cloudtrail:UpdateTrail"
    ]
    resources = [local.project_cloudtrail_arn]
  }

  statement {
    sid    = "ManageSecurityAuditEventRules"
    effect = "Allow"
    actions = [
      "events:DeleteRule",
      "events:PutRule",
      "events:PutTargets",
      "events:RemoveTargets",
      "events:TagResource",
      "events:UntagResource"
    ]
    resources = local.project_eventbridge_rule_arns
  }

  statement {
    sid    = "ManageProjectSnsTopics"
    effect = "Allow"
    actions = [
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:SetTopicAttributes",
      "sns:TagResource",
      "sns:UntagResource"
    ]
    resources = local.project_sns_topic_arns
  }

  statement {
    sid    = "CreateManagedObservabilityWorkspaces"
    effect = "Allow"
    actions = [
      "aps:CreateWorkspace",
      "grafana:CreateWorkspace"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TagManagedObservabilityWorkspacesOnCreate"
    effect = "Allow"
    actions = [
      "aps:TagResource",
      "grafana:TagResource"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Owner"
      values   = [local.standard_tags.Owner]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Application"
      values   = [local.standard_tags.Application]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"
      values   = [local.development_environment]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/ManagedBy"
      values   = [local.standard_tags.ManagedBy]
    }
  }

  statement {
    sid    = "ManageAmpWorkspace"
    effect = "Allow"
    actions = [
      "aps:DeleteWorkspace",
      "aps:TagResource",
      "aps:UntagResource",
      "aps:UpdateWorkspaceAlias"
    ]
    resources = local.project_amp_workspace_arns
  }

  statement {
    sid    = "ManageGrafanaWorkspace"
    effect = "Allow"
    actions = [
      "grafana:DeleteWorkspace",
      "grafana:TagResource",
      "grafana:UntagResource",
      "grafana:UpdateWorkspace"
    ]
    resources = local.project_grafana_workspace_arns
  }
}

resource "aws_iam_policy" "github_development_terraform_apply_observability_audit" {
  name        = "pcrp-GitHubDevelopmentTerraformApplyObservabilityAudit"
  description = "Terraform Apply CloudWatch, logs, security audit, AMP, and Grafana permissions for approved roots."
  policy      = data.aws_iam_policy_document.github_development_terraform_apply_observability_audit.json
}

resource "aws_iam_role_policy_attachment" "github_development_terraform_apply_observability_audit" {
  role       = aws_iam_role.github_development_terraform_apply.name
  policy_arn = aws_iam_policy.github_development_terraform_apply_observability_audit.arn
}

data "aws_iam_policy_document" "github_development_terraform_apply_iam" {
  statement {
    sid    = "ReadProjectIamRoleMetadata"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:ListRoleTags"
    ]
    resources = local.project_iam_role_arns
  }

  statement {
    sid       = "ReadDevelopmentOwnedInlinePolicyMetadata"
    effect    = "Allow"
    actions   = ["iam:GetRolePolicy"]
    resources = local.development_owned_iam_role_arns
  }

  statement {
    sid    = "ReadProjectManagedPolicyMetadata"
    effect = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListEntitiesForPolicy",
      "iam:ListPolicyTags",
      "iam:ListPolicyVersions"
    ]
    resources = local.project_iam_policy_arns
  }

  statement {
    sid    = "ManageDevelopmentOwnedIamRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription"
    ]
    resources = local.development_owned_iam_role_arns
  }

  statement {
    sid    = "AttachRdsEnhancedMonitoringPolicy"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      local.development_rds_enhanced_monitoring_role_arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]
    }
  }

  statement {
    sid    = "ManageEcrPublishingManagedPolicy"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy"
    ]
    resources = [local.ecr_publish_policy_arn]
  }

  statement {
    sid     = "CreateRequiredServiceLinkedRoles"
    effect  = "Allow"
    actions = ["iam:CreateServiceLinkedRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.amazonaws.com/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/elasticloadbalancing.amazonaws.com/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/grafana.amazonaws.com/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/rds.amazonaws.com/*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/wafv2.amazonaws.com/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "ecs.amazonaws.com",
        "ecs.application-autoscaling.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "grafana.amazonaws.com",
        "rds.amazonaws.com",
        "wafv2.amazonaws.com"
      ]
    }
  }

  statement {
    sid       = "PassEcsTaskRolesToEcsTasksOnly"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = local.development_workload_role_arns

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid     = "PassRdsEnhancedMonitoringRoleOnly"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      local.development_rds_enhanced_monitoring_role_arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["rds.amazonaws.com"]
    }
  }

  statement {
    sid     = "PassGrafanaWorkspaceRoleOnly"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      local.development_grafana_role_arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["grafana.amazonaws.com"]
    }
  }

}

resource "aws_iam_policy" "github_development_terraform_apply_iam" {
  name        = "pcrp-GitHubDevelopmentTerraformApplyIam"
  description = "Terraform Apply IAM permissions for downstream-owned application roles and policy attachments."
  policy      = data.aws_iam_policy_document.github_development_terraform_apply_iam.json
}

resource "aws_iam_role_policy_attachment" "github_development_terraform_apply_iam" {
  role       = aws_iam_role.github_development_terraform_apply.name
  policy_arn = aws_iam_policy.github_development_terraform_apply_iam.arn
}

data "aws_iam_policy_document" "github_development_terraform_apply_deployment_boundaries" {
  statement {
    sid    = "AttachEcrPublishPolicyToPublisherOnly"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      local.github_development_ecr_publisher_role_arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PolicyARN"
      values   = [local.ecr_publish_policy_arn]
    }
  }

  statement {
    sid    = "ManageExactEcsReleaseRuntimeManagedPolicy"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy"
    ]
    resources = [local.ecs_release_runtime_policy_arn]
  }

  statement {
    sid    = "AttachEcsReleaseRuntimePolicyToReleaseOnly"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      local.github_development_ecs_release_role_arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PolicyARN"
      values   = [local.ecs_release_runtime_policy_arn]
    }
  }

  statement {
    sid    = "DenyDeploymentRoleAdministration"
    effect = "Deny"
    actions = [
      "iam:DeleteRole",
      "iam:DeleteRolePermissionsBoundary",
      "iam:PutRolePermissionsBoundary",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription"
    ]
    resources = local.github_project_role_arns
  }

  statement {
    sid    = "DenyDeploymentRoleInlinePolicies"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePolicy",
      "iam:PutRolePolicy"
    ]
    resources = [
      local.github_development_deployment_role_arn,
      local.github_development_terraform_plan_role_arn,
      local.github_development_terraform_apply_role_arn,
      local.github_development_ecr_publisher_role_arn,
      local.github_development_ecs_release_role_arn
    ]
  }

  statement {
    sid    = "DenyManagedPolicyAttachmentsOutsideApprovedExceptions"
    effect = "Deny"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      local.github_development_deployment_role_arn,
      local.github_development_terraform_plan_role_arn,
      local.github_development_terraform_apply_role_arn
    ]
  }

  statement {
    sid    = "DenyOtherManagedPoliciesOnPublisher"
    effect = "Deny"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      local.github_development_ecr_publisher_role_arn
    ]

    condition {
      test     = "ArnNotEquals"
      variable = "iam:PolicyARN"
      values   = [local.ecr_publish_policy_arn]
    }
  }

  statement {
    sid    = "DenyOtherManagedPoliciesOnRelease"
    effect = "Deny"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]
    resources = [
      local.github_development_ecs_release_role_arn
    ]

    condition {
      test     = "ArnNotEquals"
      variable = "iam:PolicyARN"
      values   = [local.ecs_release_runtime_policy_arn]
    }
  }

  statement {
    sid    = "DenyGitHubOidcProviderMutation"
    effect = "Deny"
    actions = [
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint"
    ]
    resources = [
      aws_iam_openid_connect_provider.github_actions.arn
    ]
  }

  statement {
    sid       = "DenyGitHubOidcProviderCreation"
    effect    = "Deny"
    actions   = ["iam:CreateOpenIDConnectProvider"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_development_terraform_apply_deployment_boundaries" {
  name        = "pcrp-GitHubDevelopmentTerraformApplyDeploymentBoundaries"
  description = "Narrow downstream deployment-role exceptions and explicit control-plane denies for Terraform Apply."
  policy      = data.aws_iam_policy_document.github_development_terraform_apply_deployment_boundaries.json
}

resource "aws_iam_role_policy_attachment" "github_development_terraform_apply_deployment_boundaries" {
  role       = aws_iam_role.github_development_terraform_apply.name
  policy_arn = aws_iam_policy.github_development_terraform_apply_deployment_boundaries.arn
}
