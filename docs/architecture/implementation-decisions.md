# Implementation Decisions

## What We Are Building

The concrete Stage 0 decisions that unblock implementation for the five-hour AWS Production Cloud Reliability Platform build.

## Why It Exists In Production

Architecture documents should not leave critical implementation choices implicit. These decisions define the first live environment and prevent Terraform, CI/CD, networking, observability, and application implementation from making conflicting assumptions.

## Environment

- AWS Region: `us-east-1`
- GitHub repository: `production-cloud-reliability-platform`
- GitHub default branch: `main`
- GitHub deployment environment: `production`
- Platform environment name: `production`

Only one live environment will be built during the five-hour delivery. Additional environments can be introduced later.

## Public Entry

- Use temporary ALB DNS first.
- Add ACM and HTTPS if it is quick.
- Defer HTTPS briefly if certificate/domain work threatens the live milestone.
- Route 53 custom domain can be added after the ALB endpoint is live.

## Network And Egress

- ECS and RDS should remain private where appropriate.
- Use NAT Gateway initially for private subnet egress.
- Revisit VPC endpoints later for cost and security optimization.

## Database

- Use RDS PostgreSQL.
- First build: Single-AZ.
- Backup retention: 7 days.
- Backups remain managed by RDS.

## Async Processing

- Use SQS standard queue with DLQ.
- Visibility timeout: 60 seconds initially.
- Max receives before DLQ: 3.
- Worker deletes messages only after durable completion.

## Object Storage

- Use S3 for generated CSV reports.
- S3 object key pattern: `reports/{job_id}/{report_id}.csv`
- PostgreSQL stores report metadata, object key, object type, creation timestamp, and ownership/reference information.
- Orphan cleanup strategy: S3 lifecycle policy plus an operational reconciliation script.

## Observability

- CloudWatch log retention: 1 day.
- CloudWatch alarms should publish state through an SNS topic.
- Prometheus runs as an ECS service.
- Grafana runs as an ECS service if it does not threaten the live milestone.
- WAF is deferred to Hour 5 if time permits.
- OpenTelemetry is deferred unless implementation remains safely ahead of schedule.

## Terraform State

- Use a dedicated S3 state bucket.
- Use locking for state safety.
- Preferred first implementation: S3 backend with a DynamoDB lock table unless the selected Terraform version and team preference support an equivalent simpler locking mode.

## Standard Tags

- `Owner = Chisom`
- `Application = ProductionCloudReliabilityPlatform`
- `Environment = production`
- `ManagedBy = Terraform`
