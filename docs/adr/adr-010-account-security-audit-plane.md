# ADR-010: Account Security Audit Plane: Multi-Region CloudTrail + Targeted EventBridge Security Alerts

## Status

Accepted.

## Context

Runtime observability exists, but application logs and ECS telemetry cannot answer who changed AWS infrastructure, from where, and through which AWS API action.

The project remains single-account today and is cost-conscious. It has no current requirement for a customer-managed KMS key, CloudTrail Lake, CloudTrail Insights, organization trail, or broad data-event logging.

Security events need a durable audit record and selected near-real-time notification for high-risk control-plane actions.

## Decision

Create an account-level multi-Region CloudTrail trail with global service events, read/write management events, S3 durable log delivery, SSE-S3 audit bucket encryption, and log file validation.

Create targeted EventBridge rules for root activity, CloudTrail tampering, IAM privilege changes, network perimeter changes, S3 security posture changes, and console login without MFA. Send those events to a dedicated security SNS topic.

Do not create subscriptions until an actual endpoint is supplied. Do not enable broad data events, CloudTrail Insights, CloudTrail Lake, CloudTrail to CloudWatch Logs delivery, customer-managed KMS, Object Lock, remediation automation, or organization trail.

## Alternatives

1. Event History only.
2. Trail plus S3 only.
3. Trail plus full CloudWatch Logs streaming.
4. CloudTrail Lake.
5. Full organization-wide security account architecture.
6. Selected hybrid model.

The selected hybrid model is chosen.

## Consequences

Positive:

- durable audit history
- multi-Region control-plane visibility
- global service event coverage
- integrity validation capability
- selected near-real-time security notifications
- controlled cost
- no application runtime dependency

Negative:

- no object-level data-event audit
- no CloudTrail Lake SQL query experience
- no centralized multi-account immutability
- SNS notification delivery is incomplete until a real subscriber is configured
- audit bucket is not Object-Lock immutable

## Review Triggers

- AWS Organizations or multi-account adoption
- compliance retention requirement
- object-access auditing requirement
- SIEM integration
- SQL investigation requirement
- security team requires immutable retention
- CloudTrail data-event requirement
- CloudTrail Insights requirement

