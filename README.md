# AWS Production Cloud Reliability Platform

Production-minded AWS platform for hands-on DevOps and SRE interview preparation.

This project is intentionally small at the application layer and serious at the platform layer. The application exists to create realistic operational behavior: HTTP traffic, database activity, asynchronous jobs, logs, metrics, alerts, deployments, failures, troubleshooting, and recovery.

## Stage Status

Current stage: Stage 1 - Local application foundation.

Stage 1 adds the local FastAPI API, PostgreSQL schema, Nginx reverse proxy, async job interface, worker foundation, structured logging, Prometheus metrics endpoint, Docker Compose workflow, shell scripts, and focused tests. It still does not include Terraform, AWS resources, or CI/CD workflows.

## What We Are Building

A FastAPI-based service deployed on AWS ECS Fargate behind an Application Load Balancer, backed by RDS PostgreSQL and SQS, with CloudWatch observability, Secrets Manager, IAM least privilege, GitHub Actions OIDC deployments, and incident-response runbooks.

The target architecture is:

```text
Internet
  -> Route 53
  -> Application Load Balancer
  -> ECS Fargate API service
  -> RDS PostgreSQL

API service
  -> SQS queue
  -> ECS Fargate worker service
  -> RDS PostgreSQL

Application and platform events
  -> CloudWatch Logs, Metrics, Alarms, Dashboards
  -> CloudTrail
```

## Why It Exists In Production

The platform demonstrates how production systems are designed, deployed, observed, broken, diagnosed, recovered, and improved. It is meant to prepare an engineer to explain operational trade-offs in an interview, not to showcase a complicated business domain.

## Stage 0 Documents

- [System Context](docs/architecture/system-context.md)
- [Requirements](docs/architecture/requirements.md)
- [Initial AWS Architecture](docs/architecture/initial-aws-architecture.md)
- [Data Flow](docs/architecture/data-flow.md)
- [Trust Boundaries](docs/architecture/trust-boundaries.md)
- [Major Failure Modes](docs/architecture/failure-modes.md)
- [Repository Structure](docs/architecture/repository-structure.md)
- [Implementation Decisions](docs/architecture/implementation-decisions.md)
- [ADR Index](docs/adr/README.md)
- [Implementation Roadmap](docs/operations/implementation-roadmap.md)

## Stage 1 Documents

- [Local Development](docs/operations/local-development.md)
- [Stage 1 Local Application](docs/operations/stage-1-local-application.md)
- [Stage 1 Nginx Upstream Failure Drill](docs/incidents/stage-1-nginx-upstream-failure.md)
- [Continuous Integration](docs/operations/continuous-integration.md)

## Stage 2A Documents

- [Terraform Bootstrap](infrastructure/bootstrap/README.md)

## Stage 1 Local Commands

Install Python 3.11 or newer for tests, then:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env
docker compose up --build -d
```

Call the API through Nginx:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/ready
```

Run tests:

```bash
pytest
```

## Initial Repository Structure

```text
.
+-- README.md
+-- docs/
|   +-- adr/
|   |   +-- README.md
|   +-- architecture/
|   |   +-- data-flow.md
|   |   +-- failure-modes.md
|   |   +-- initial-aws-architecture.md
|   |   +-- repository-structure.md
|   |   +-- requirements.md
|   |   +-- system-context.md
|   |   +-- trust-boundaries.md
|   +-- operations/
|       +-- implementation-roadmap.md
+-- infrastructure/
+-- services/
+-- scripts/
+-- tests/
```

Implementation directories are now introduced for the Stage 1 local application foundation.

## Next Stage

Stage 1 should create the local FastAPI and worker foundation with PostgreSQL and SQS-compatible local development patterns, before AWS infrastructure is implemented.
