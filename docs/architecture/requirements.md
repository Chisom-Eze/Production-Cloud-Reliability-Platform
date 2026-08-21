# Requirements

## What We Are Building

The requirements baseline for a small production-style AWS reliability platform that must prioritize a live deployment within five focused hours.

## Why It Exists In Production

Requirements make the platform defendable. They explain what the system must do, what qualities matter, and which trade-offs are intentional before implementation begins.

## Functional Requirements

The platform must provide:

- AWS deployment in `us-east-1`.
- GitHub repository name `production-cloud-reliability-platform` for CI/CD and OIDC scoping.
- A public REST API with `GET /health`, `GET /ready`, `GET /customers`, `POST /customers`, `POST /jobs`, and `GET /jobs/{id}`.
- API traffic through Route 53, ALB, Nginx sidecar, and FastAPI.
- Persistent transactional storage in RDS PostgreSQL.
- Asynchronous job submission and worker processing through SQS.
- SQS dead-letter queue for failed messages.
- Durable S3 object storage for generated reports, CSV/PDF exports, uploaded documents, or application artifacts.
- PostgreSQL storage for S3 object metadata, object key, object type, creation timestamp, and ownership/reference information.
- Structured centralized logs for API, worker, and Nginx.
- Correlation or request IDs across request handling and background processing.
- Health checks and dependency readiness checks.
- Deployment through GitHub Actions.
- AWS authentication from GitHub Actions using OIDC.
- Infrastructure managed by Terraform.
- CloudWatch logs, AWS metrics, alarms, and dashboards.
- Prometheus application metrics for request count, latency, 4xx, 5xx, active requests, jobs processed, and worker failures where practical.
- Grafana dashboard covering application, ECS, SQS, and RDS health where practical.
- At least one controlled incident, preferably API 502/504, with a short postmortem.
- At least two useful Bash operational scripts.
- At least one useful Python/boto3 operational tool.
- Documentation explaining architecture, security controls, deployment, rollback, troubleshooting, observability, incidents, and cost drivers.

## Non-Functional Requirements

### Delivery

- A working live deployment is the primary success criterion.
- Optional tooling must be deferred if it threatens the working deployment.
- No non-critical enhancement should block progress for more than 15-20 minutes.

### Reliability

- API and worker services should run across multiple Availability Zones where practical.
- Nginx must run as a sidecar per API task, not as a standalone singleton.
- RDS should be private and protected from direct internet access.
- Health checks should allow ECS and ALB to detect failed API/Nginx tasks.
- Worker processing should tolerate duplicate SQS delivery.
- SQS messages should be deleted only after durable processing succeeds.
- Partial failures between S3 and PostgreSQL must be documented and handled deliberately.
- Rollback must be documented and tested where practical.

### Security

- No long-lived AWS credentials in GitHub.
- No hard-coded secrets in source code or Dockerfiles.
- Separate ECS task role and execution role.
- Least-privilege IAM policies.
- Private subnets for ECS tasks and RDS where appropriate.
- Restricted security groups.
- Secure S3 configuration with public access blocked.
- Encryption at rest for supported managed services.
- Secrets Manager for runtime secrets.
- CloudTrail enabled for audit visibility.
- WAF where practical.

### Observability

- CloudWatch should centralize AWS logs, AWS-native metrics, alarms, and dashboards.
- Logs should be structured JSON where practical.
- Nginx access logs should capture request status, path, latency, request ID, and upstream behavior.
- Application logs should include timestamp, level, service, request ID, correlation ID, endpoint, status, latency, and error details.
- Prometheus should expose application/service metrics where practical.
- Grafana should provide one useful operational dashboard if time allows.
- OpenTelemetry tracing is optional and should be deferred if it threatens the deadline.

### Maintainability

- Terraform modules should be clear and limited in scope.
- Only one `production` environment is required during the five-hour delivery.
- Module boundaries should allow staging/production environments later.
- Application and infrastructure code should use explicit configuration.
- Documentation should explain why controls exist, not only how to run commands.

### Operability

- Engineers should have a documented local workflow.
- Deployment and smoke testing should be predictable.
- Runbooks should guide investigation and recovery.
- Failure scenarios should be reproducible in controlled ways.
- Scripts should have clear arguments, useful output, and meaningful exit codes.

### FinOps

- Cost drivers must be documented.
- NAT Gateway, RDS, ALB, ECS, CloudWatch, S3, Grafana/Prometheus hosting, and data transfer costs should be understood.
- The first implementation should avoid over-provisioning.

## Out Of Scope

- Kubernetes, Helm, ArgoCD, CDK, CloudFormation, and OpenTofu.
- A complex business application.
- Separate staging and production environments during the five-hour delivery.
- Multi-region active-active architecture.
- Elaborate SRE frameworks beyond basic SLIs, SLOs, and error budget reasoning.
- OpenTelemetry if it threatens the live deployment timeline.
