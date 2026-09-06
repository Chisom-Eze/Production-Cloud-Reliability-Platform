# Security Audit Module

This module creates the account/control-plane security audit baseline:

- one dedicated CloudTrail S3 audit bucket
- one account-level multi-Region CloudTrail trail
- management read/write event logging
- CloudTrail log file validation
- one dedicated security notification SNS topic
- targeted EventBridge rules for selected high-risk control-plane activity

## CloudTrail

The trail is account-level, multi-Region, includes global service events, records read and write management events, and enables log file validation.

It is not an organization trail. It does not enable data events, network activity events, CloudTrail Insights, CloudTrail Lake, or CloudTrail delivery to CloudWatch Logs.

## Audit Bucket

The audit bucket is separate from application artifacts, ALB access logs, and Terraform state. It uses Public Access Block, BucketOwnerEnforced object ownership, versioning, SSE-S3 with `AES256`, `force_destroy = false`, and a TLS-only deny statement.

The CloudTrail delivery policy allows only `s3:GetBucketAcl` and scoped `s3:PutObject` for `cloudtrail.amazonaws.com`, constrained by the exact trail ARN and CloudTrail delivery ACL condition.

Stage L does not enable S3 Object Lock or MFA Delete.

## Security Events

EventBridge rules target the dedicated security SNS topic for:

- root activity
- CloudTrail tampering
- IAM privilege changes
- network perimeter changes
- S3 security posture changes
- successful console login without MFA

The rules detect and notify. They do not remediate or mutate infrastructure.

The SNS topic has no email, chat, incident-management, SIEM, or SOC subscription in this module.

