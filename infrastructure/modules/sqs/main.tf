locals {
  queue_name = "${var.project_display_name}-${var.environment}-jobs"
  dlq_name   = "${var.project_display_name}-${var.environment}-jobs-dlq"
}

resource "aws_sqs_queue" "dlq" {
  name = local.dlq_name

  delay_seconds              = 0
  message_retention_seconds  = var.dlq_message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = var.visibility_timeout_seconds

  tags = {
    Name = local.dlq_name
  }
}

resource "aws_sqs_queue" "main" {
  name = local.queue_name

  delay_seconds              = 0
  message_retention_seconds  = var.message_retention_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = var.visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name = local.queue_name
  }
}

resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.main.arn]
  })
}

data "aws_iam_policy_document" "main_tls" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["sqs:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [aws_sqs_queue.main.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "main_tls" {
  queue_url = aws_sqs_queue.main.id
  policy    = data.aws_iam_policy_document.main_tls.json
}

data "aws_iam_policy_document" "dlq_tls" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["sqs:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [aws_sqs_queue.dlq.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "dlq_tls" {
  queue_url = aws_sqs_queue.dlq.id
  policy    = data.aws_iam_policy_document.dlq_tls.json
}
