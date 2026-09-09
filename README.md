# Production Cloud Reliability Platform

A production-oriented AWS platform engineering and reliability project built around a small FastAPI workload.

The objective is not simply to provision cloud resources. The repository is designed to exercise the engineering decisions required to build, secure, observe, release, troubleshoot, and recover a distributed production system.

The project deliberately combines:

* AWS solution architecture
* Terraform and Infrastructure as Code
* GitHub Actions and GitHub OIDC
* ECS/Fargate
* Docker and Linux
* PostgreSQL/RDS
* SQS and event-driven processing
* S3 durable artifact storage
* transactional outbox patterns
* distributed-system reliability
* observability
* IAM and cloud security
* release engineering
* incident response
* SRE and FinOps decision-making

The development model is:

```text
design
  -> implement
  -> review
  -> validate
  -> deploy
  -> deliberately break
  -> troubleshoot
  -> recover
  -> explain the architecture and trade-offs
```

The repository distinguishes clearly between infrastructure that is **implemented and statically validated** and infrastructure that has been **actually deployed and runtime-tested in AWS**.

## Architecture

### Request Path

```text
Client
  |
  v
Route 53
  |
  v
AWS WAF
  |
  v
Application Load Balancer
HTTPS / ACM
  |
  v
Nginx
  |
  v
FastAPI
  |
  v
PostgreSQL / RDS
```

Nginx and FastAPI run in the same ECS Fargate task.

The ALB targets Nginx on port `80`.

FastAPI listens on port `8000` inside the shared `awsvpc` task network namespace and is not directly exposed through the ALB or application security group.

### Asynchronous Processing

```text
FastAPI
  |
  | PostgreSQL transaction
  v
job + transactional outbox
  |
  v
worker outbox dispatcher
  |
  v
SQS Standard Queue
  |
  v
worker consumer
  |
  +--> processing / retry / idempotency
  |
  +--> S3 artifact
  |
  v
durable PostgreSQL completion
```

The API does **not** directly publish application jobs to SQS.

Instead, job creation and the corresponding outbox record are written atomically in the same PostgreSQL transaction. The worker later dispatches the outbox record to SQS.

This avoids the database/SQS dual-write problem.

Generated report objects follow the contract:

```text
reports/{job_id}/{report_id}.csv
```

## Application Components

| Component      | Responsibility                                                      | Repository status |
| -------------- | ------------------------------------------------------------------- | ----------------- |
| FastAPI        | Health, readiness, customers and job APIs                           | Implemented       |
| Nginx          | Reverse proxy, headers, access logging and timeout boundary         | Implemented       |
| PostgreSQL     | Transactional state, jobs, outbox and artifact references           | Implemented       |
| Worker         | Outbox dispatch, SQS consumption, processing and durable completion | Implemented       |
| SQS            | At-least-once asynchronous delivery with DLQ                        | Terraform-defined |
| S3             | Durable generated artifact storage                                  | Terraform-defined |
| ECS Fargate    | API and worker runtime                                              | Terraform-defined |
| RDS PostgreSQL | Managed application database                                        | Terraform-defined |
| ALB            | Public application ingress                                          | Terraform-defined |
| WAF            | Managed-rule and rate-limit perimeter                               | Terraform-defined |
| Route 53 / ACM | DNS and TLS                                                         | Terraform-defined |

## Reliability Model

### Liveness And Readiness

The application deliberately separates:

```text
GET /health
```

Process liveness only.

```text
GET /ready
```

Dependency readiness, including PostgreSQL.

Database instability should not cause unnecessary ECS container churn, so `/ready` is not used as container liveness.

### SQS Semantics

The worker is designed for SQS Standard Queue semantics:

* at-least-once delivery
* duplicate messages
* possible ordering differences
* 60-second visibility timeout
* visibility heartbeat
* 20-second long polling
* maximum receive count of 3
* DLQ isolation
* four-day main queue retention
* fourteen-day DLQ retention

The worker implements:

* idempotency
* database claims
* processing tokens / fencing
* stale-lease reclamation
* SQS visibility extension
* duplicate handling
* durable completion
* message deletion only after durable success

### Transactional Outbox

Application requests do not depend on successfully publishing to SQS during the HTTP transaction.

Instead:

```text
database transaction
  -> create job
  -> create outbox record
  -> commit
```

The worker owns the subsequent dispatch.

This provides a recoverable boundary between transactional state and asynchronous delivery.

## AWS Infrastructure

Primary region:

```text
us-east-1
```

### Network

Development VPC:

```text
10.10.0.0/16
```

Two Availability Zones are used:

```text
us-east-1a
us-east-1b
```

Network tiers:

```text
Public
  10.10.0.0/24
  10.10.1.0/24

Application private
  10.10.10.0/24
  10.10.11.0/24

Database private
  10.10.20.0/24
  10.10.21.0/24
```

Development deliberately uses one NAT Gateway as a cost trade-off.

The network module supports:

```text
single
per_az
none
```

Production can later move to per-AZ NAT if reliability requirements justify the additional cost.

Database subnets have no Internet or NAT default route.

An S3 Gateway VPC Endpoint is implemented for application-private route tables.

Paid interface endpoints remain deferred until traffic, security, and cost evidence justify them.

## Security Group Model

```text
Internet
  -> ALB :80/:443

ALB
  -> API ECS :80

API ECS / Worker ECS
  -> RDS :5432

Worker
  -> no inbound application traffic
```

FastAPI port `8000` is not exposed externally.

Workload egress is deliberately constrained rather than using unrestricted all-protocol rules.

## ECS / Fargate

Runtime target:

```text
AWS ECS
Fargate
awsvpc
Linux x86_64
```

API task:

```text
FastAPI
Nginx
ADOT sidecar
```

Worker task:

```text
worker
ADOT sidecar
```

Database migrations run as a separate one-off ECS task using the API image:

```text
python -m application.migrations
```

ECS deployment circuit breaker and rollback are enabled in Terraform.

Desired-count changes are ignored by Terraform so Application Auto Scaling does not fight Terraform state.

### Autoscaling

API:

```text
CPU target:    60%
Memory target: 70%
```

Worker:

```text
ApproximateNumberOfMessagesVisible
----------------------------------
RunningTaskCount
```

Development scaling range:

```text
minimum: 1
maximum: 4
```

The worker intentionally does not scale to zero because it is also responsible for transactional-outbox dispatch.

## RDS PostgreSQL

Development configuration intentionally favors cost control while retaining managed-database behavior.

Current design includes:

* private database subnets
* Single-AZ development deployment
* `db.t4g.micro`
* gp3 storage
* 20 GiB initial storage
* storage autoscaling up to 100 GiB
* seven-day backups
* storage encryption
* RDS-managed master password through Secrets Manager
* PostgreSQL and upgrade logging
* Enhanced Monitoring
* required final snapshot

Development intentionally does not currently enable:

* RDS Proxy
* read replicas
* IAM database authentication
* Performance Insights
* deletion protection
* AWS Backup integration

These are architectural decisions, not missing scanner remediations.

## Storage And Encryption Policy

The project does not introduce customer-managed KMS keys simply because a scanner recommends them.

Current policy:

| Service                     | Encryption decision                                        |
| --------------------------- | ---------------------------------------------------------- |
| S3 artifacts                | SSE-S3 / AES256                                            |
| Terraform state             | SSE-S3                                                     |
| ECR                         | AES256                                                     |
| SQS                         | SQS-managed server-side encryption                         |
| RDS / EBS / Secrets Manager | AWS/service-managed encryption where inherently KMS-backed |

Customer-managed keys will be added only when there is a concrete security, compliance, audit, or key-management requirement.

This is a deliberate security / complexity / FinOps trade-off.

## Observability

Responsibilities are intentionally separated.

### CloudWatch

Used for:

* AWS infrastructure metrics
* service metrics
* ECS deployment signals
* alarms
* autoscaling control signals
* AWS logs
* Container Insights

### Prometheus / Amazon Managed Service For Prometheus

Used for:

* application metrics
* platform metrics
* SLI/SLO time series

### Grafana / Amazon Managed Grafana

Used for:

* dashboards
* cross-signal operational visualization

### OpenTelemetry / ADOT

Used for:

* instrumentation
* context propagation
* collection
* telemetry export

### AWS X-Ray

Used as the trace backend.

Telemetry is not allowed to become a business-processing dependency.

If AMP, Grafana, X-Ray, or ADOT fails:

```text
business processing continues
```

Implemented observability code and Terraform include:

* structured JSON logging
* request IDs
* correlation IDs
* trace IDs
* span IDs
* bounded Prometheus labels
* AMP
* AMG
* X-Ray
* ADOT
* CloudWatch alarms
* Container Insights
* dashboard/query definitions
* runbooks
* SLI/SLO operating contracts

Final production SLO values and burn-rate paging thresholds remain intentionally deferred until runtime evidence exists.

## Security Audit Plane

A shared account-level security-audit Terraform root defines:

* multi-Region CloudTrail
* global service events
* management events
* CloudTrail log validation
* private/versioned/encrypted audit storage
* EventBridge security detections
* security SNS notifications

Detection patterns include:

* root-user activity
* CloudTrail tampering
* IAM privilege changes
* network perimeter changes
* S3 posture changes
* successful console login without MFA

The project intentionally does not yet add every possible security service.

Examples currently deferred include:

* CloudTrail Lake
* CloudTrail Insights
* broad data-event logging
* Object Lock
* customer-managed KMS keys
* SIEM integration
* automated remediation
* GuardDuty / Security Hub expansion

These will be added only when the operating model justifies them.

## Terraform Architecture

Terraform does not use workspaces.

Independent root modules own independent state.

Current roots:

```text
infrastructure/bootstrap

infrastructure/shared/container-registry

infrastructure/shared/security-audit

infrastructure/environments/development
```

Future environment roots:

```text
infrastructure/environments/staging
infrastructure/environments/production
```

Those remain placeholders until the project reaches environment promotion.

Principle:

```text
one AWS resource
  ->
one Terraform owner
```

Reusable Terraform modules include:

```text
acm-dns
alb
ecr
ecs
ecs-autoscaling
observability
rds
s3-artifacts
security-audit
security-groups
sqs
vpc
vpc-endpoints
waf
workload-iam
```

A legacy duplicate IAM module was removed after proving that the active architecture uses `workload-iam`.

## Terraform State

Terraform bootstrap infrastructure has been applied and remote state established.

State uses:

* dedicated S3 storage
* native S3 locking
* versioning
* Public Access Block
* SSE-S3
* IAM-controlled access

Local Terraform is intentionally limited to static operations such as:

```bash
terraform fmt
terraform init -backend=false
terraform validate
tflint
trivy
```

Local `terraform apply` is not part of this project workflow.

Infrastructure deployment will use GitHub Actions and GitHub OIDC.

## CI And Security Gates

### Application CI

```text
Ruff
pytest
Docker build validation
Docker Compose validation
Nginx configuration validation
```

### Infrastructure CI

The canonical Terraform quality implementation is:

```bash
bash scripts/terraform-quality.sh
```

It validates all real Terraform roots using:

* `terraform fmt -check`
* `terraform init -backend=false`
* read-only lockfile mode where lockfiles already exist
* `terraform validate`
* TFLint
* Trivy informational LOW/MEDIUM scan
* Trivy blocking HIGH/CRITICAL scan

Static Terraform CI does not:

```text
authenticate to AWS
initialize the remote backend
run terraform plan
run terraform apply
```

### Application And Supply-Chain Security

Current controls include:

* Bandit
* pip-audit
* Gitleaks
* Hadolint
* Trivy container scanning

Scanner findings are treated as engineering evidence, not automatic architecture instructions.

A security recommendation may be:

```text
remediated
accepted as an explicit trade-off
documented/suppressed
deferred to production hardening
```

depending on actual risk and system requirements.

## Release Engineering Model

The intended release path is:

```text
pull request
  -> application / security / Terraform quality gates
  -> authenticated Terraform plan
  -> reviewed infrastructure apply
  -> build API / worker / Nginx once
  -> scan images
  -> publish to ECR
  -> capture immutable image digests
  -> run database migration task
  -> require migration success
  -> deploy API and worker services
  -> verify health / readiness / observability
```

The same immutable image digest should eventually be promoted:

```text
development
  -> staging
  -> production
```

Images are not intended to be rebuilt separately for each environment.

Rollback uses a previous known-good digest.

## Git Workflow

`main` is the durable source of truth.

Development uses short-lived task branches:

```text
main
  -> short-lived branch
  -> commit
  -> push
  -> pull request
  -> CI
  -> merge to main
  -> delete local branch
  -> delete remote branch
  -> synchronize main
```

Long-lived implementation branches are intentionally avoided.

## Repository Structure

```text
application/
  FastAPI application, worker, Nginx and Dockerfiles

infrastructure/
  Terraform roots and reusable modules

scripts/
  local and CI quality helpers

docs/
  architecture, operations, runbooks and engineering decisions

.github/workflows/
  application, Terraform, and security CI workflows

tests/
  application and worker tests
```

A legacy `services/platform_app` tree remains from an earlier iteration and is not considered the promoted application path. Its removal will be handled only after repository references are verified.

## Running Locally

```bash
docker compose up --build -d

docker compose ps

curl http://localhost:8080/health

curl http://localhost:8080/ready

docker compose down
```

The API is accessed through Nginx on port `8080`.

## Local Quality Verification

Application:

```bash
ruff check application tests
pytest
docker compose config
```

Terraform:

```bash
bash scripts/terraform-quality.sh
```

Application and supply-chain security:

```bash
bash scripts/security-quality.sh
```

Repository integrity:

```bash
git grep -nE '^(<<<<<<<|=======|>>>>>>>)' || true
```

The expected repository-integrity result is no output.

## Current Delivery Status

### Implemented In The Repository

* FastAPI application
* Nginx reverse proxy
* PostgreSQL data model
* transactional outbox
* SQS worker reliability model
* durable S3 artifact contract
* Docker images
* Terraform modular architecture
* four real Terraform roots
* VPC and security groups
* ECS/Fargate runtime definitions
* RDS
* ALB
* Route 53 / ACM
* WAF
* ECR
* SQS / DLQ
* S3 artifacts
* ECS autoscaling
* observability
* VPC S3 Gateway Endpoint
* shared security-audit plane
* application CI
* Terraform static CI
* application and supply-chain security CI
* GitHub OIDC identity and authentication proof

M-B2 is currently hardening repository integrity, deterministic provider selection, and CI consistency before the first controlled authenticated development deployment.

### AWS-Verified

The following foundations have been explicitly verified:

* Terraform bootstrap / remote-state foundation
* GitHub OIDC federation
* GitHub-to-AWS STS role assumption

### Not Yet Claimed As Deployed

The complete development runtime platform has not yet undergone its first controlled authenticated Terraform deployment.

Still required before that milestone:

* finish repository/CI consistency hardening
* complete deterministic provider-lock policy
* complete deployment IAM
* implement authenticated Terraform plan/apply workflow
* implement immutable ECR publication
* implement migration-before-service deployment gating
* perform the first controlled development apply
* validate runtime networking and application behavior
* validate observability and alarms
* perform failure/recovery drills

No runtime AWS behavior is considered proven until deployment evidence exists.

## Current Engineering Stage

The current milestone is:

```text
M-B2
CI consistency
+ deterministic providers
+ repository integrity
```

The immediate work includes:

* complete root-module dependency lockfile coverage
* prevent unresolved merge markers from entering the repository again
* remove local/GitHub quality-gate drift
* pin nondeterministic CI tooling
* resolve the AWS-provider ALB deprecation
* classify informational Trivy findings as accepted, documented, genuine hardening, or production-only requirements

Authenticated deployment work begins only after M-B2 is completed and validated.

## Planned Failure Exercise

After the development environment is deployed and verified, one planned incident drill is:

```text
break Nginx upstream
  -> generate HTTP 502 responses
  -> observe ALB / application / CloudWatch / metrics / traces
  -> triage
  -> identify root cause
  -> recover
  -> validate alarms and runbooks
```

The purpose is to practice operational reasoning, not simply demonstrate a successful deployment.

## Engineering Principle

This project treats production engineering as more than provisioning resources.

The standard is:

```text
Can the architecture be explained?

Can its trade-offs be defended?

Can it be deployed safely?

Can failure be detected?

Can the failure be diagnosed?

Can the system recover?

Can the decisions be justified with evidence?
```

That is the objective of the Production Cloud Reliability Platform.
