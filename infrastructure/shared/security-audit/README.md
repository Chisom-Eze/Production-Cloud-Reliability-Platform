# Shared Security Audit

This root owns the account/control-plane audit layer for the project.

It creates one multi-Region account CloudTrail trail, one dedicated CloudTrail audit bucket, one dedicated security SNS topic, and targeted EventBridge rules through `infrastructure/modules/security-audit`.

## State Boundary

This is a standalone shared Terraform root with its own backend block and intended state key:

```text
shared/security-audit/terraform.tfstate
```

It must not be duplicated in development, staging, or production environment roots.

## Backend

Use partial S3 backend configuration. Do not commit real backend credentials.

The local backend config should be created from:

```text
backend.s3.tfbackend.example
```

Use native S3 state locking with `use_lockfile = true`. Do not create a DynamoDB locking table.

## Scope

This root does not create application runtime resources, VPC endpoints, workload IAM changes, GuardDuty, Security Hub, Inspector, Macie, AWS Config, CloudTrail Lake, CloudTrail Insights, Object Lock, KMS keys, SIEM integrations, or remediation automation.

