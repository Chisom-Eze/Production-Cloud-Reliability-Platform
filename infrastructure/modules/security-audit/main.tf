data "aws_caller_identity" "current" {}

locals {
  name_prefix              = var.project_name
  trail_name               = "${local.name_prefix}-account-audit"
  cloudtrail_trail_arn     = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
  cloudtrail_log_prefix    = trim(var.cloudtrail_log_prefix, "/")
  cloudtrail_object_prefix = local.cloudtrail_log_prefix == "" ? "AWSLogs/${data.aws_caller_identity.current.account_id}" : "${local.cloudtrail_log_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}"

  security_event_rule_arns = [
    aws_cloudwatch_event_rule.root_activity.arn,
    aws_cloudwatch_event_rule.cloudtrail_tampering.arn,
    aws_cloudwatch_event_rule.iam_privilege_change.arn,
    aws_cloudwatch_event_rule.network_perimeter_change.arn,
    aws_cloudwatch_event_rule.s3_security_change.arn,
    aws_cloudwatch_event_rule.console_login_without_mfa.arn
  ]
}

resource "aws_s3_bucket" "audit" {
  bucket_prefix = var.audit_bucket_prefix
  force_destroy = false

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-audit"
  })
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket = aws_s3_bucket.audit.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_iam_policy_document" "audit_bucket" {
  statement {
    sid     = "AllowCloudTrailBucketAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    resources = [aws_s3_bucket.audit.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.cloudtrail_trail_arn]
    }
  }

  statement {
    sid     = "AllowCloudTrailLogDelivery"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.audit.arn}/${local.cloudtrail_object_prefix}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.cloudtrail_trail_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.audit.arn,
      "${aws_s3_bucket.audit.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = data.aws_iam_policy_document.audit_bucket.json
}

resource "aws_cloudtrail" "account_audit" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.audit.id
  s3_key_prefix                 = local.cloudtrail_log_prefix == "" ? null : local.cloudtrail_log_prefix
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  enable_logging                = true
  is_organization_trail         = false

  event_selector {
    include_management_events = true
    read_write_type           = "All"
  }

  tags = merge(var.tags, {
    Name = local.trail_name
  })

  depends_on = [aws_s3_bucket_policy.audit]
}

resource "aws_sns_topic" "security_notifications" {
  name = "${local.name_prefix}-security-notifications"

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-security-notifications"
  })
}

resource "aws_cloudwatch_event_rule" "root_activity" {
  name        = "${local.name_prefix}-root-activity-critical"
  description = "Critical security visibility for root user API activity."

  event_pattern = jsonencode({
    "detail-type" = ["AWS API Call via CloudTrail"]
    detail = {
      userIdentity = {
        type = ["Root"]
      }
    }
  })

  tags = merge(var.tags, {
    Severity = "critical"
  })
}

resource "aws_cloudwatch_event_rule" "cloudtrail_tampering" {
  name        = "${local.name_prefix}-cloudtrail-tampering-critical"
  description = "Critical security visibility for CloudTrail configuration tampering."

  event_pattern = jsonencode({
    "detail-type" = ["AWS API Call via CloudTrail"]
    source        = ["aws.cloudtrail"]
    detail = {
      eventSource = ["cloudtrail.amazonaws.com"]
      eventName = [
        "StopLogging",
        "DeleteTrail",
        "UpdateTrail",
        "PutEventSelectors",
        "PutInsightSelectors"
      ]
    }
  })

  tags = merge(var.tags, {
    Severity = "critical"
  })
}

resource "aws_cloudwatch_event_rule" "iam_privilege_change" {
  name        = "${local.name_prefix}-iam-privilege-change-warning"
  description = "Security visibility for material IAM privilege changes."

  event_pattern = jsonencode({
    "detail-type" = ["AWS API Call via CloudTrail"]
    source        = ["aws.iam"]
    detail = {
      eventSource = ["iam.amazonaws.com"]
      eventName = [
        "AttachRolePolicy",
        "AttachUserPolicy",
        "AttachGroupPolicy",
        "PutRolePolicy",
        "PutUserPolicy",
        "PutGroupPolicy",
        "CreatePolicyVersion",
        "SetDefaultPolicyVersion",
        "UpdateAssumeRolePolicy",
        "CreateAccessKey",
        "DeleteAccessKey",
        "UpdateLoginProfile",
        "CreateLoginProfile"
      ]
    }
  })

  tags = merge(var.tags, {
    Severity = "warning"
  })
}

resource "aws_cloudwatch_event_rule" "network_perimeter_change" {
  name        = "${local.name_prefix}-network-perimeter-change-warning"
  description = "Security visibility for material ingress, egress, and routing changes."

  event_pattern = jsonencode({
    "detail-type" = ["AWS API Call via CloudTrail"]
    source        = ["aws.ec2"]
    detail = {
      eventSource = ["ec2.amazonaws.com"]
      eventName = [
        "AuthorizeSecurityGroupIngress",
        "AuthorizeSecurityGroupEgress",
        "RevokeSecurityGroupIngress",
        "RevokeSecurityGroupEgress",
        "CreateRoute",
        "ReplaceRoute",
        "DeleteRoute",
        "CreateNetworkAclEntry",
        "ReplaceNetworkAclEntry",
        "DeleteNetworkAclEntry"
      ]
    }
  })

  tags = merge(var.tags, {
    Severity = "warning"
  })
}

resource "aws_cloudwatch_event_rule" "s3_security_change" {
  name        = "${local.name_prefix}-s3-security-change-warning"
  description = "Security visibility for S3 bucket policy, exposure, encryption, and ownership changes."

  event_pattern = jsonencode({
    "detail-type" = ["AWS API Call via CloudTrail"]
    source        = ["aws.s3"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName = [
        "PutBucketPolicy",
        "DeleteBucketPolicy",
        "PutBucketPublicAccessBlock",
        "DeletePublicAccessBlock",
        "PutBucketEncryption",
        "DeleteBucketEncryption",
        "PutBucketOwnershipControls",
        "DeleteBucketOwnershipControls"
      ]
    }
  })

  tags = merge(var.tags, {
    Severity = "warning"
  })
}

resource "aws_cloudwatch_event_rule" "console_login_without_mfa" {
  name        = "${local.name_prefix}-console-login-without-mfa-warning"
  description = "Security visibility for successful console login events where MFA was not used."

  event_pattern = jsonencode({
    "detail-type" = ["AWS Console Sign In via CloudTrail"]
    source        = ["aws.signin"]
    detail = {
      eventName = ["ConsoleLogin"]
      responseElements = {
        ConsoleLogin = ["Success"]
      }
      additionalEventData = {
        MFAUsed = ["No"]
      }
    }
  })

  tags = merge(var.tags, {
    Severity = "warning"
  })
}

data "aws_iam_policy_document" "security_notifications" {
  statement {
    sid     = "AllowEventBridgeSecurityRulesToPublish"
    effect  = "Allow"
    actions = ["sns:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.security_notifications.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = local.security_event_rule_arns
    }
  }
}

resource "aws_sns_topic_policy" "security_notifications" {
  arn    = aws_sns_topic.security_notifications.arn
  policy = data.aws_iam_policy_document.security_notifications.json
}

resource "aws_cloudwatch_event_target" "root_activity" {
  rule      = aws_cloudwatch_event_rule.root_activity.name
  target_id = "SecurityNotifications"
  arn       = aws_sns_topic.security_notifications.arn

  depends_on = [aws_sns_topic_policy.security_notifications]
}

resource "aws_cloudwatch_event_target" "cloudtrail_tampering" {
  rule      = aws_cloudwatch_event_rule.cloudtrail_tampering.name
  target_id = "SecurityNotifications"
  arn       = aws_sns_topic.security_notifications.arn

  depends_on = [aws_sns_topic_policy.security_notifications]
}

resource "aws_cloudwatch_event_target" "iam_privilege_change" {
  rule      = aws_cloudwatch_event_rule.iam_privilege_change.name
  target_id = "SecurityNotifications"
  arn       = aws_sns_topic.security_notifications.arn

  depends_on = [aws_sns_topic_policy.security_notifications]
}

resource "aws_cloudwatch_event_target" "network_perimeter_change" {
  rule      = aws_cloudwatch_event_rule.network_perimeter_change.name
  target_id = "SecurityNotifications"
  arn       = aws_sns_topic.security_notifications.arn

  depends_on = [aws_sns_topic_policy.security_notifications]
}

resource "aws_cloudwatch_event_target" "s3_security_change" {
  rule      = aws_cloudwatch_event_rule.s3_security_change.name
  target_id = "SecurityNotifications"
  arn       = aws_sns_topic.security_notifications.arn

  depends_on = [aws_sns_topic_policy.security_notifications]
}

resource "aws_cloudwatch_event_target" "console_login_without_mfa" {
  rule      = aws_cloudwatch_event_rule.console_login_without_mfa.name
  target_id = "SecurityNotifications"
  arn       = aws_sns_topic.security_notifications.arn

  depends_on = [aws_sns_topic_policy.security_notifications]
}
