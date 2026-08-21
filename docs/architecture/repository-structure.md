# Repository Structure

## What We Are Building

The initial repository layout for a five-hour production-style AWS reliability platform.

## Why It Exists In Production

A predictable repository structure helps engineers find application code, infrastructure, CI/CD definitions, scripts, tests, observability configuration, and operational documentation quickly during normal work and incidents.

## Target Structure

```text
.
+-- .github/
|   +-- workflows/
+-- README.md
+-- application/
|   +-- api/
|   +-- worker/
|   +-- nginx/
|   +-- shared/
|   +-- Dockerfile.api
|   +-- Dockerfile.worker
+-- docs/
|   +-- adr/
|   +-- architecture/
|   +-- incidents/
|   +-- observability/
|   +-- operations/
|   +-- runbooks/
+-- infrastructure/
|   +-- environments/
|   |   +-- production/
|   +-- modules/
|       +-- alb/
|       +-- ecs/
|       +-- iam/
|       +-- network/
|       +-- observability/
|       +-- rds/
|       +-- s3/
|       +-- sqs/
+-- scripts/
+-- tests/
```

## Directory Ownership

### `.github/workflows`

GitHub Actions CI/CD workflows. Later implementation will add pull request checks, Docker builds, Terraform validation, Terraform plan, OIDC authentication, deployment, and smoke tests.

### `application`

FastAPI API, SQS worker, shared Python code, Nginx sidecar configuration, and Dockerfiles.

### `docs/adr`

Architecture Decision Records. ADRs explain why major technology and design decisions were made.

### `docs/architecture`

System context, requirements, architecture, trust boundaries, data flows, and failure-mode design.

### `docs/incidents`

Incident scenario write-ups and postmortems. The first required incident should be an API 502/504 scenario unless another controlled failure is more practical.

### `docs/observability`

CloudWatch, Prometheus, Grafana, logging, metrics, dashboards, and optional tracing documentation.

### `docs/operations`

Operational guides such as deployment, rollback, disaster recovery, troubleshooting, security model, and FinOps notes.

### `docs/runbooks`

Step-by-step procedures for responding to alerts and incidents.

### `infrastructure`

Terraform root module for `production` and reusable modules for network, ALB, ECS, RDS, SQS, S3, IAM, and observability. Additional environments can be introduced later without changing the core module model.

### `scripts`

Bash and Python operational tooling, including at least two Bash scripts and at least one boto3-based Python tool.

### `tests`

Automated tests for application behavior, worker behavior, scripts, and later infrastructure checks where practical.

## Repository Principle

The repository should prioritize a working AWS deployment over exhaustive folder completeness. Empty directories should not be created unless they are immediately useful or documented as part of the implementation stage.
