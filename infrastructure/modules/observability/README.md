# Observability Module

This module creates the managed observability foundation:

- Amazon Managed Service for Prometheus workspace
- Amazon Managed Grafana workspace
- AWS X-Ray trace-write IAM support for ECS task roles
- AMP remote-write IAM support for ECS task roles
- SNS alarm topic
- deterministic CloudWatch alarms
- development CloudWatch dashboard
- CloudWatch Logs Insights query definitions

OpenTelemetry is not a backend. ADOT collectors scrape local Prometheus endpoints and receive local OTLP traces, then export metrics to AMP and traces to X-Ray. Structured stdout logs remain in CloudWatch Logs through ECS `awslogs`.

## IAM

ECS task roles receive `aps:RemoteWrite` scoped to the AMP workspace. X-Ray trace write actions use `Resource = "*"` because those write APIs do not support resource-level scoping in the same way as AMP workspaces.

Amazon Managed Grafana uses a customer-managed read-only role trusted by `grafana.amazonaws.com`. Some CloudWatch Logs, CloudWatch Metrics, and X-Ray read/list APIs require wildcard resources; the role does not grant write access to ECS, RDS, SQS, S3, or IAM.

## Alarms

The module creates deterministic alarms for DLQ messages and unhealthy ALB targets. SLO-dependent thresholds are explicit inputs and must come from measured behavior or business requirements.

## Non-Goals

This module does not create self-hosted Prometheus, self-hosted Grafana, OpenTelemetry collectors, VPC endpoints, KMS keys, email/SMS subscriptions, incident-management workflows, or application health dependencies on telemetry systems.
