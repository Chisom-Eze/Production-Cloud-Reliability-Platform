# Architecture Decision Records

## What We Are Building

The initial ADR list for the five-hour AWS Production Cloud Reliability Platform.

## Why It Exists In Production

ADRs make decisions explicit. They help an engineer explain not only what was built, but why it was chosen over reasonable alternatives.

## ADR List

### ADR-001: AWS ECS Fargate vs ECS On EC2

Initial decision:

- Use ECS Fargate.

Trade-off:

- Fargate reduces host patching, node capacity management, and EC2 operational work. ECS on EC2 gives more control and may be cheaper at scale, but it increases host-management burden during a time-limited build.

### ADR-002: RDS PostgreSQL vs Self-Managed PostgreSQL

Initial decision:

- Use Amazon RDS PostgreSQL in private database subnets.

Trade-off:

- RDS provides managed backups, monitoring, patching paths, and production-like database operations. Self-managed PostgreSQL gives deeper OS/database control but distracts from the cloud reliability platform goal.

### ADR-003: SQS For Asynchronous Processing

Initial decision:

- Use SQS with an ECS worker service and DLQ.

Trade-off:

- SQS adds queue semantics, duplicate-delivery handling, visibility timeout, retry, and DLQ behavior. Direct synchronous processing is simpler but creates less useful reliability and incident surface.

### ADR-004: S3 For Durable Application Artifacts

Initial decision:

- Use S3 for generated reports, exported artifacts, uploaded documents, or application files. Store object metadata and references in PostgreSQL.

Trade-off:

- S3 is durable and cost-effective for objects, while PostgreSQL remains the right home for transactional state and relationships. The trade-off is handling partial failures between object upload and metadata update.

### ADR-005: GitHub OIDC Instead Of Long-Lived Credentials

Initial decision:

- Use GitHub Actions OIDC with scoped IAM trust policies.

Trade-off:

- OIDC requires careful trust-policy setup, but avoids storing long-lived AWS credentials in GitHub and supports repository, branch, and environment scoping.

### ADR-006: CloudWatch + Prometheus + Grafana Observability Model

Initial decision:

- Use CloudWatch for AWS-native logs, metrics, alarms, and dashboards. Use Prometheus for application/service metrics and Grafana for one useful operational dashboard where practical.

Trade-off:

- CloudWatch alone is simpler and AWS-native. Prometheus/Grafana add application metric visibility and common SRE tooling experience, but they must stay small enough not to threaten the live deployment.

### ADR-007: Nginx Sidecar Trade-Off

Initial decision:

- Run Nginx as a sidecar in each API ECS task: ALB -> Nginx -> FastAPI.

Trade-off:

- Nginx demonstrates reverse proxy concepts, access logging, timeout handling, security headers, and upstream diagnostics. ALB directly to FastAPI is simpler and often preferable when the application can handle these concerns cleanly. The sidecar must scale with API tasks so Nginx does not become a single point of failure.

### ADR-008: Separate Immutable ECR Repositories Per Service

Initial decision:

- Use separate ECR repositories for API, worker, and Nginx images with immutable Git-SHA tags.

Trade-off:

- Separate repositories keep permissions, scanning evidence, lifecycle policy, and operational ownership clear per deployable component. A single repository with service-prefixed tags would be simpler to create, but it makes least-privilege IAM and per-component cleanup harder to reason about. Immutable tags prevent accidental replacement of reviewed artifacts; rollbacks will use previously captured image digests rather than mutable names such as `latest`.

### ADR-009: Selective AWS-Service Routing: S3 Gateway Endpoint + Retained NAT

Initial decision:

- Keep the existing NAT Gateway and add a regional S3 Gateway VPC Endpoint for application-private route tables only.

Trade-off:

- The hybrid model moves same-Region S3 traffic, including application artifacts and ECR image-layer downloads, away from NAT without adding endpoint hourly charge. NAT remains for external APIs and AWS services whose interface endpoints are intentionally deferred until cost, security, or availability evidence justifies them.

Full record:

- [ADR-009](adr-009-selective-aws-service-routing.md)

### ADR-010: Account Security Audit Plane: Multi-Region CloudTrail + Targeted EventBridge Security Alerts

Initial decision:

- Use a shared account-level multi-Region CloudTrail trail, dedicated audit bucket, targeted EventBridge security rules, and dedicated security SNS topic.

Trade-off:

- The selected audit plane provides durable account control-plane history, log file validation, and selected near-real-time notification without adding CloudTrail Lake, broad data events, Insights, Object Lock, CMK, SIEM integration, or automated remediation cost/complexity. It is not a full enterprise security platform and should be revisited when compliance, multi-account, immutable-retention, or data-event requirements emerge.

Full record:

- [ADR-010](adr-010-account-security-audit-plane.md)

## ADR Template For Later Stages

Each ADR should include:

- Context
- Decision
- Alternatives
- Trade-offs
- Consequences
