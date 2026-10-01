locals {
  ecs_release_runtime_policy_name = "pcrp-GitHubDevelopmentEcsReleaseRuntime"

  ecs_release_api_service_name    = module.ecs.api_service_configured_name
  ecs_release_worker_service_name = module.ecs.worker_service_configured_name

  ecs_release_migration_task_definition_arn = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${module.ecs.migration_task_definition_family}:*"

  ecs_release_service_arns = [
    "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${module.ecs.cluster_name}/${local.ecs_release_api_service_name}",
    "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${module.ecs.cluster_name}/${local.ecs_release_worker_service_name}"
  ]

  ecs_release_task_arns = [
    "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task/${module.ecs.cluster_name}/*"
  ]

  ecs_release_log_group_arns = [
    module.ecs.api_log_group_arn,
    "${module.ecs.api_log_group_arn}:*",
    module.ecs.nginx_log_group_arn,
    "${module.ecs.nginx_log_group_arn}:*",
    module.ecs.worker_log_group_arn,
    "${module.ecs.worker_log_group_arn}:*"
  ]

  ecs_release_pass_role_arns = [
    module.workload_iam.api_execution_role_arn,
    module.workload_iam.api_task_role_arn,
    module.workload_iam.worker_execution_role_arn,
    module.workload_iam.worker_task_role_arn
  ]
}

data "aws_iam_policy_document" "github_development_ecs_release_runtime" {
  statement {
    sid     = "RunMigrationTaskOnDevelopmentCluster"
    effect  = "Allow"
    actions = ["ecs:RunTask"]
    resources = [
      local.ecs_release_migration_task_definition_arn
    ]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [module.ecs.cluster_arn]
    }
  }

  statement {
    sid    = "ObserveAndCleanUpMigrationTasks"
    effect = "Allow"
    actions = [
      "ecs:DescribeTasks",
      "ecs:StopTask"
    ]
    resources = local.ecs_release_task_arns

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [module.ecs.cluster_arn]
    }
  }

  statement {
    sid    = "ReadApprovedTaskDefinitions"
    effect = "Allow"
    actions = [
      "ecs:DescribeTaskDefinition"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PromoteApiAndWorkerServices"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]
    resources = local.ecs_release_service_arns
  }

  statement {
    sid       = "PassWorkloadRolesToEcsTasksOnly"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = local.ecs_release_pass_role_arns

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid    = "ReadReleaseEvidenceLogs"
    effect = "Allow"
    actions = [
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogEvents"
    ]
    resources = local.ecs_release_log_group_arns
  }

  statement {
    sid    = "ReadTargetGroupHealth"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeTargetHealth"
    ]
    resources = [
      module.alb.target_group_arn
    ]
  }

  statement {
    sid    = "DenyTerraformOwnedEcsMutation"
    effect = "Deny"
    actions = [
      "ecs:CreateCluster",
      "ecs:CreateService",
      "ecs:DeleteCluster",
      "ecs:DeleteService",
      "ecs:DeregisterTaskDefinition",
      "ecs:RegisterTaskDefinition"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_development_ecs_release_runtime" {
  name        = local.ecs_release_runtime_policy_name
  description = "Runtime permissions for migration execution and ECS service promotion in development."
  policy      = data.aws_iam_policy_document.github_development_ecs_release_runtime.json
}

resource "aws_iam_role_policy_attachment" "github_development_ecs_release_runtime" {
  role       = var.github_development_ecs_release_role_name
  policy_arn = aws_iam_policy.github_development_ecs_release_runtime.arn
}
