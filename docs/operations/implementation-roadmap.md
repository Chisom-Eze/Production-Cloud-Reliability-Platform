# Five-Hour Implementation Roadmap

## What We Are Building

An execution plan for getting a small production-style AWS reliability platform live within five focused hours.

## Why It Exists In Production

The plan optimizes for a working deployed system over architectural perfection. Optional enhancements should be deferred if they threaten the primary success criterion: a live, reproducible, observable AWS deployment with CI/CD and one diagnosed incident.

## Primary Success Criterion

At the end of the session:

- The application is live on AWS.
- A user can call the API successfully.
- CI/CD deploys automatically.
- GitHub Actions authenticates to AWS through OIDC.
- Logging and baseline observability work.
- PostgreSQL, SQS, and S3 perform real application functions.
- Terraform can reproduce the infrastructure.
- At least one controlled production failure is demonstrated and diagnosed.
- Documentation explains how the system works and how to troubleshoot it.

## Fixed Implementation Inputs

- AWS Region: `us-east-1`
- GitHub repository: `production-cloud-reliability-platform`
- Branch: `main`
- GitHub environment: `production`
- Public endpoint: temporary ALB DNS first
- Egress: NAT Gateway initially
- RDS: Single-AZ with 7 days managed backup retention
- SQS: 60 second visibility timeout, 3 max receives, DLQ enabled
- S3 artifact: generated CSV report at `reports/{job_id}/{report_id}.csv`
- Observability: CloudWatch with 1 day log retention, SNS alarm topic, Prometheus ECS service, Grafana ECS service if time permits
- Terraform state: dedicated S3 state bucket with locking
- Standard tags: `Owner=Chisom`, `Application=ProductionCloudReliabilityPlatform`, `Environment=production`, `ManagedBy=Terraform`

## Hour 1: Foundation

Goal:

- Create the smallest useful local application foundation and verify it locally.

Deliverables:

- Repository structure.
- FastAPI application.
- PostgreSQL schema.
- API and worker Dockerfiles.
- Nginx sidecar configuration.
- Local application test.
- Git setup where practical.

Stop and verify:

- API responds locally.
- Database schema exists.
- Worker path is testable.
- Containers build.

## Hour 2: AWS Foundation

Goal:

- Get the application live on AWS.

Deliverables:

- VPC and security groups.
- ECR repositories.
- RDS PostgreSQL.
- S3 bucket.
- SQS queue and DLQ.
- IAM roles and policies.
- Secrets Manager secret.
- ECS cluster, API service, worker service.
- ALB routing to Nginx sidecar.

Stop and verify:

- ALB endpoint responds.
- ECS tasks are healthy.
- API can reach RDS, SQS, and S3.

## Hour 3: CI/CD

Goal:

- Make commit-to-deployment work through GitHub Actions and OIDC.

Deliverables:

- Pull request workflow with lint, tests, Terraform fmt, Terraform validate, Terraform plan, and Docker build.
- Main workflow with OIDC authentication, immutable image build, ECR push, infrastructure deploy where required, ECS deploy, smoke tests, and health verification.
- OIDC trust policy scoped to repository, branch, and environment.

Stop and verify:

- GitHub Actions assumes AWS role without static credentials.
- A main-branch change deploys to ECS.
- Smoke test proves service health.

## Hour 4: Observability And Reliability

Goal:

- See the system when healthy and when failing.

Deliverables:

- CloudWatch log groups for API, worker, and Nginx.
- Structured logs.
- CloudWatch metrics and alarms for ALB/ECS/SQS/RDS basics.
- Prometheus application/service metrics where practical.
- One useful Grafana dashboard where practical.
- SQS/DLQ monitoring.
- SLI/SLO documentation for availability, latency, and error rate.

Stop and verify:

- Logs are visible centrally.
- Metrics show request and worker behavior.
- Baseline alarms exist.

## Hour 5: Incident And Documentation

Goal:

- Prove the platform can fail, be diagnosed, and recover.

Deliverables:

- Controlled 502/504 incident, preferably Nginx upstream, app port, health check, or startup failure.
- Detection, triage, logs, metrics, root cause, recovery.
- Short postmortem.
- Final architecture diagram.
- Runbook.
- README.
- Clean-state deployment verification.

Stop and verify:

- Incident is documented with evidence.
- Service is restored.
- User can explain the failure and recovery path.

## Delivery Rule

Do not spend more than 15-20 minutes blocked on a non-critical enhancement. If a feature threatens the working deployment, defer it, document it, and continue.

## Deferred By Default Unless Time Allows

- OpenTelemetry tracing.
- Sophisticated multi-environment Terraform estate.
- Full WAF rule tuning.
- Advanced Grafana dashboard polish.
- Advanced database optimization.
- Complex Git branch protection automation.
