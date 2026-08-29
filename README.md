# Production Cloud Reliability Platform

Production-style cloud reliability platform built around a small FastAPI workload. The repository is designed to exercise real delivery, infrastructure, observability, security, asynchronous processing, and incident-response patterns without turning the application domain into the main project.

The platform is intentionally incremental. Local application, CI, Terraform bootstrap, remote state, OIDC federation, Terraform static quality gates, and application/supply-chain security gates exist today. Runtime AWS application infrastructure and deployment workflows are planned next stages.

## Architecture

Target application flow:

```text
Client
  -> ALB
  -> Nginx
  -> FastAPI
  -> PostgreSQL / SQS / S3

SQS
  -> worker
  -> generated CSV report
  -> S3
```

Current local flow:

```text
Client
  -> Nginx on Docker Compose
  -> FastAPI
  -> PostgreSQL
```

PostgreSQL stores transactional state and S3 object metadata/references. S3 is the durable object store for generated artifacts such as:

```text
reports/{job_id}/{report_id}.csv
```

Observability is designed around structured logs, correlation IDs, CloudWatch for AWS-native logs/metrics/alarms, Prometheus for application metrics, and Grafana for operational dashboards. OpenTelemetry is deferred unless it fits a later delivery window without threatening the live milestone.

## Application Components

| Component | Responsibility | Current status |
| --- | --- | --- |
| FastAPI API | Health, readiness, customer, job, and metrics endpoints | Implemented locally |
| Nginx | Reverse proxy, forwarded headers, access logs, timeouts, security headers | Implemented locally |
| PostgreSQL | Transactional state for customers, jobs, results, audit events, object metadata | Implemented locally |
| Worker | Foundation for asynchronous job processing and report metadata flow | Implemented locally |
| SQS | Production async queue with DLQ, retries, duplicate-delivery handling | Planned AWS stage |
| S3 | Durable generated CSV report storage | Planned AWS stage |

<<<<<<< HEAD
## Reliability Model
=======
- [Terraform Bootstrap](infrastructure/bootstrap/README.md)
- [Terraform CI Static Quality Gates](docs/operations/terraform-ci.md)
>>>>>>> origin/main

The application separates liveness and readiness:

- `/health` proves the API process is alive.
- `/ready` checks dependency readiness and fails when PostgreSQL is unavailable.

Asynchronous work is modeled as a database-backed job record plus a queue boundary. The production design uses SQS with a DLQ, 60 second visibility timeout, three max receives, idempotent processing, and durable CSV artifacts in S3.

Controlled failure drills are documented for Nginx upstream failures, including the distinction between gateway errors caused by proxy/upstream connectivity and application-level failures visible in FastAPI logs.

## Infrastructure

Terraform bootstrap infrastructure has been applied and migrated to remote state.

Verified infrastructure decisions:

- AWS region: `us-east-1`
- Terraform state is stored in a dedicated S3 bucket.
- S3 native state locking uses `use_lockfile = true`.
- State bucket versioning is enabled.
- State bucket public access is blocked.
- State bucket encryption uses SSE-S3 as an accepted cost/complexity trade-off.
- GitHub OIDC provider and development deployment role exist.
- GitHub to AWS STS role assumption has been successfully verified.

Sensitive infrastructure values such as AWS account IDs, state bucket names, credentials, and private ARNs are intentionally not documented in this README.

## CI/CD And Release Engineering

Current release-control model:

```text
feature/fix branch
  -> pull request
  -> CI, security, and IaC quality gates
  -> protected/promoted main
```

Deployment environments are distinct from Git branches. The planned delivery model is:

```text
main
  -> build once
  -> immutable artifact
  -> development
  -> staging
  -> production
```

The project uses GitHub OIDC rather than long-lived AWS access keys. ECR publication, ECS deployment, and authenticated Terraform plan/apply workflows are not implemented yet.

## Quality And Security Gates

| Control | Purpose | Scope |
| --- | --- | --- |
| Ruff | Python quality and correctness linting | `application/`, `tests/` |
| pytest | Application behavior tests | `tests/` |
| Docker Compose validation | Local service topology validation | `docker-compose.yml` |
| Nginx validation | Reverse proxy configuration syntax | `application/nginx/default.conf` |
| `terraform fmt` | Canonical Terraform formatting | `infrastructure/` |
| `terraform validate` | Static Terraform configuration validity | Terraform roots |
| TFLint | Terraform and AWS provider quality checks | Terraform roots |
| Trivy IaC | Infrastructure misconfiguration scanning | `infrastructure/` |
| Bandit | Python SAST | `application/` |
| pip-audit | Python dependency vulnerability scanning | `requirements.txt` |
| Gitleaks | Secret scanning with redacted output | Git history |
| Hadolint | Dockerfile construction analysis | Existing Dockerfiles |
| Trivy image scan | Container image vulnerability scanning | API, worker, Nginx runtime image |

Security findings are reviewed as gates or risk decisions. Scanners do not automatically rewrite promoted implementation.

SSE-S3 is intentionally retained for Terraform state in this project as a documented cost/complexity trade-off; the bucket remains private, versioned, encrypted, and IAM-controlled.

## Repository Structure

```text
application/          FastAPI API, worker foundation, Nginx config, Dockerfiles
infrastructure/       Terraform bootstrap and future infrastructure roots/modules
scripts/              Local operational and quality-gate helper scripts
docs/                 Architecture, operations, incident, and CI documentation
.github/workflows/   CI, Terraform static quality, and security workflows
tests/                Application and worker tests
```

Legacy `services/` files remain in the workspace from earlier iteration work and are not part of the current promoted application path.

## Running Locally

```bash
docker compose up --build -d
docker compose ps
curl http://localhost:8080/health
curl http://localhost:8080/ready
docker compose down
```

The API is reached through Nginx on port `8080`.

## CI And Local Quality Verification

Application checks:

```bash
ruff check application tests
pytest
docker compose config
docker build -f application/Dockerfile.api -t production-cloud-reliability-platform-api:local .
docker build -f application/Dockerfile.worker -t production-cloud-reliability-platform-worker:local .
```

Terraform static checks:

```bash
bash scripts/terraform-quality.sh
```

Application and supply-chain security checks:

```bash
bash scripts/security-quality.sh
```

## Engineering Decisions And Trade-Offs

- ECS Fargate is the target runtime instead of Kubernetes to focus on AWS-native reliability operations.
- PostgreSQL stores transactional state and relationships.
- S3 stores durable generated objects, not relational state.
- SQS provides asynchronous job processing, retry behavior, and DLQ failure isolation.
- Nginx is included as a deliberate reverse-proxy and web-server operations exercise.
- GitHub OIDC is used instead of static AWS credentials.
- SSE-S3 is accepted for Terraform state encryption in this project.
- Single-AZ RDS is the first deployment target as a cost trade-off; Multi-AZ is a later hardening step.
- NAT Gateway is the initial private workload egress choice for implementation simplicity.
- CloudWatch and Prometheus/Grafana have distinct observability roles.

## Current Delivery Status

Completed:

- Local application vertical slice
- Docker/Nginx integration
- Application CI quality pipeline
- Terraform bootstrap
- Remote Terraform state with S3 native locking
- GitHub OIDC federation proof
- Terraform static quality gates
- Application and supply-chain security gates
- Docker build-context hardening

In progress / next:

- Authenticated Terraform plan
- ECR immutable artifact publication
- Runtime AWS infrastructure
- ECS deployment
- Cloud observability
- Environment promotion
- Rollback validation

## Operational And Security Constraints

- No long-lived AWS credentials in GitHub.
- No secrets committed to source.
- Terraform state is remote, encrypted, versioned, private, and locked.
- Security findings are treated as gates or documented risk decisions.
- Production changes flow through pull requests and promoted branches.
