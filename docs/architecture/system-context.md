# System Context

## What We Are Building

An AWS Production Cloud Reliability Platform that can be delivered in a focused five-hour build window.

The platform uses a deliberately small FastAPI application to demonstrate production operations rather than product complexity. The application creates realistic behavior across HTTP requests, PostgreSQL transactions, SQS async processing, S3 artifact storage, structured logs, metrics, alerts, deployment automation, and incident response.

The target system includes:

- Public API traffic through Route 53 and an Application Load Balancer.
- Nginx as a sidecar reverse proxy in the API ECS task.
- FastAPI API service running on ECS Fargate.
- Worker service running on ECS Fargate.
- PostgreSQL transactional state using Amazon RDS.
- SQS queue and dead-letter queue for asynchronous work.
- S3 durable object storage for generated reports, exports, documents, or artifacts.
- Object metadata and S3 object references stored in PostgreSQL.
- Secrets stored in AWS Secrets Manager.
- CloudWatch logs, AWS metrics, alarms, and dashboards.
- Prometheus application metrics and Grafana operational dashboard.
- GitHub Actions deployment using AWS OIDC.
- CloudTrail audit visibility.
- WAF where practical within the delivery window.

## Why It Exists In Production

Production platforms are more than application code. They include networking, identity, deployment safety, observability, incident response, cost awareness, and operational documentation.

This project is optimized for a working live AWS deployment that an engineer can explain in an interview. Optional enhancements must not threaten the working deployment.

## Actors

- End user: Sends API requests through the public endpoint.
- Developer: Changes application or infrastructure code through Git and pull requests.
- GitHub Actions: Runs CI checks and deploys through AWS OIDC.
- Platform operator: Observes service health, investigates incidents, and performs rollback or recovery.
- AWS control plane: Manages ECS, RDS, SQS, S3, IAM, Secrets Manager, CloudWatch, CloudTrail, and related services.

## External Systems

- GitHub: Source control and CI/CD runner environment.
- AWS: Runtime platform, managed services, identity, logging, monitoring, and audit controls.

## System Boundary

Inside the project boundary:

- Application source code.
- Worker source code.
- Nginx sidecar configuration.
- Docker build definitions.
- Terraform infrastructure definitions.
- CI/CD workflows.
- Operational scripts.
- Prometheus/Grafana configuration where practical.
- Runbooks, ADRs, incident documents, and architecture documentation.

Outside the project boundary:

- GitHub's hosted runner infrastructure.
- AWS managed service internals.
- User-owned DNS domain registration, unless configured through Route 53 later.

## Recommended Stage 0 Decisions

- Use ECS Fargate instead of ECS on EC2 for reduced host-management burden.
- Use Nginx as an API task sidecar to demonstrate reverse proxy concepts, access logging, timeout handling, and security headers.
- Keep the Nginx sidecar horizontally scaled with API tasks so it does not become a single point of failure.
- Use RDS PostgreSQL for transactional state and relationships.
- Use S3 only for durable object artifacts such as reports, exports, uploads, and generated files.
- Store S3 object keys, metadata, ownership, and references in PostgreSQL.
- Use SQS with a DLQ for asynchronous jobs.
- Use CloudWatch for AWS-native logs, metrics, alarms, and dashboards.
- Use Prometheus for application/service metrics and Grafana for an operational dashboard if it does not threaten the live deployment.
- Treat OpenTelemetry tracing as optional; defer it if it threatens the five-hour delivery goal.
- Use GitHub OIDC instead of long-lived AWS access keys.
- Keep Kubernetes, CloudFormation, CDK, and OpenTofu out of scope.
