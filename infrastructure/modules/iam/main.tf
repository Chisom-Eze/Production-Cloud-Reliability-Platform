locals {
  role_name_prefix       = "${var.project_slug}-${var.environment}"
  artifact_object_arn    = "${var.artifact_bucket_arn}/${var.artifact_object_prefix}"
  api_log_stream_arns    = ["${var.api_log_group_arn}:*", "${var.nginx_log_group_arn}:*"]
  worker_log_stream_arns = ["${var.worker_log_group_arn}:*"]
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_execution" {
  name               = "${local.role_name_prefix}-api-execution"
  description        = "ECS execution role for the API and Nginx containers."
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${local.role_name_prefix}-api-execution"
  }
}

resource "aws_iam_role" "api_task" {
  name               = "${local.role_name_prefix}-api-task"
  description        = "Application task role for the API workload."
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${local.role_name_prefix}-api-task"
  }
}

resource "aws_iam_role" "worker_execution" {
  name               = "${local.role_name_prefix}-worker-execution"
  description        = "ECS execution role for the worker container."
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${local.role_name_prefix}-worker-execution"
  }
}

resource "aws_iam_role" "worker_task" {
  name               = "${local.role_name_prefix}-worker-task"
  description        = "Application task role for the worker workload."
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${local.role_name_prefix}-worker-task"
  }
}

data "aws_iam_policy_document" "api_execution" {
  statement {
    sid       = "GetEcrAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PullApiAndNginxImages"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [
      var.api_ecr_repository_arn,
      var.nginx_ecr_repository_arn
    ]
  }

  statement {
    sid    = "WriteApiAndNginxLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = local.api_log_stream_arns
  }

  statement {
    sid       = "ReadDatabaseSecretForEcsInjection"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.database_secret_arn]
  }
}

resource "aws_iam_role_policy" "api_execution" {
  name   = "api-execution-least-privilege"
  role   = aws_iam_role.api_execution.id
  policy = data.aws_iam_policy_document.api_execution.json
}

data "aws_iam_policy_document" "api_task" {
  statement {
    sid       = "SendJobs"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [var.job_queue_arn]
  }
}

resource "aws_iam_role_policy" "api_task" {
  name   = "api-task-least-privilege"
  role   = aws_iam_role.api_task.id
  policy = data.aws_iam_policy_document.api_task.json
}

data "aws_iam_policy_document" "worker_execution" {
  statement {
    sid       = "GetEcrAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PullWorkerImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [var.worker_ecr_repository_arn]
  }

  statement {
    sid    = "WriteWorkerLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = local.worker_log_stream_arns
  }

  statement {
    sid       = "ReadDatabaseSecretForEcsInjection"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.database_secret_arn]
  }
}

resource "aws_iam_role_policy" "worker_execution" {
  name   = "worker-execution-least-privilege"
  role   = aws_iam_role.worker_execution.id
  policy = data.aws_iam_policy_document.worker_execution.json
}

data "aws_iam_policy_document" "worker_task" {
  statement {
    sid    = "ConsumeJobs"
    effect = "Allow"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage"
    ]
    resources = [var.job_queue_arn]
  }

  statement {
    sid    = "ReadWriteReportArtifacts"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [local.artifact_object_arn]
  }
}

resource "aws_iam_role_policy" "worker_task" {
  name   = "worker-task-least-privilege"
  role   = aws_iam_role.worker_task.id
  policy = data.aws_iam_policy_document.worker_task.json
}
