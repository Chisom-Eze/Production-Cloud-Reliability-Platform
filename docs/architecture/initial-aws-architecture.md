# Initial AWS Architecture

## What We Are Building

An initial AWS architecture for a small production-style API, reverse proxy sidecar, worker, transactional database, object storage, queue, and observability platform.

## Why It Exists In Production

This architecture separates public entry points from private compute and data services, uses managed AWS services where they reduce operational burden, and creates realistic surfaces for deployment, observability, troubleshooting, and security discussions.

## High-Level Architecture

```text
Users
  |
  v
Route 53
  |
  v
Application Load Balancer - public subnets
  |
  v
ECS Fargate API task - private subnets
  |
  +--> Nginx sidecar
        |
        v
      FastAPI container
        |
        +--> RDS PostgreSQL - transactional state and S3 metadata
        |
        +--> SQS queue and DLQ - async job dispatch
        |
        +--> S3 bucket - durable generated artifacts

SQS queue
  |
  v
ECS Fargate worker service - private subnets
  |
  +--> RDS PostgreSQL - job state and object metadata
  |
  +--> S3 bucket - report/artifact uploads

API, worker, Nginx, ECS, ALB, SQS, RDS, S3
  |
  v
CloudWatch Logs, Metrics, Alarms, Dashboards

Application/service metrics
  |
  v
Prometheus
  |
  v
Grafana dashboard

AWS account activity
  |
  v
CloudTrail
```

## Core AWS Components

### Network

- VPC across at least two Availability Zones where practical.
- Public subnets for ALB and NAT Gateway if required.
- Private application subnets for ECS tasks.
- Private database subnets for RDS.
- Route tables that keep RDS unreachable from the internet.

### Compute

- ECS Fargate API service.
- Each API task includes an Nginx sidecar and a FastAPI container.
- ECS Fargate worker service consumes SQS messages.
- ECS service discovery is optional because ALB and SQS provide the primary integration paths.

### Load Balancing And Reverse Proxy

- Application Load Balancer receives public HTTP or HTTPS traffic.
- ALB target group forwards traffic to the Nginx sidecar port.
- Nginx reverse proxies to FastAPI inside the same task.
- Nginx provides access logging, timeout behavior, security headers, and health-check handling.
- A simpler ALB-to-application design is valid in production when the app framework can own these concerns directly.

### Data

- Amazon RDS PostgreSQL stores customers, jobs, job results, audit events, and object metadata.
- PostgreSQL remains the source of truth for transactional state and relationships.
- RDS credentials are stored in Secrets Manager.

### Object Storage

- S3 stores durable objects such as generated reports, exports, uploaded documents, and application artifacts.
- S3 does not store transactional state.
- PostgreSQL stores the S3 object key, object type, creation timestamp, and ownership/reference metadata.

### Async Processing

- SQS stores job messages.
- SQS DLQ isolates messages that repeatedly fail.
- Worker service polls SQS, validates jobs, writes durable results, uploads artifacts to S3, updates PostgreSQL, and deletes messages after success.

### Identity And Secrets

- ECS task execution role pulls images and writes logs.
- ECS task role allows application access to specific AWS APIs such as SQS, S3, and Secrets Manager.
- GitHub Actions deployment role is assumed through OIDC and scoped to repository, branch, and environment.

### Observability And Audit

- CloudWatch Logs receives API, worker, and Nginx logs.
- CloudWatch Metrics and Alarms monitor AWS service health and dependencies.
- CloudWatch Dashboard shows AWS platform status.
- Prometheus collects application/service metrics where practical.
- Grafana displays one useful operational dashboard covering application, ECS, SQS, and RDS.
- OpenTelemetry tracing is optional and should be deferred if it threatens the five-hour deployment.
- CloudTrail records AWS API activity for audit and troubleshooting.

## Public And Private Boundaries

- Public: Route 53 record and ALB listener.
- Private: ECS tasks, Nginx sidecars, FastAPI containers, workers, RDS, SQS access through IAM, S3 access through IAM, Secrets Manager, CloudWatch log ingestion.
- Administrative: GitHub Actions assumes an AWS IAM role through OIDC for deployment.

## Meaningful Alternatives

- ECS EC2 instead of Fargate: More host control, but more operational burden. Fargate is recommended to focus on service reliability rather than instance lifecycle management.
- ALB directly to FastAPI instead of Nginx sidecar: Simpler and often preferable, but Nginx is included here to demonstrate reverse proxy operations, access logs, timeout handling, and security headers.
- Lambda instead of ECS worker: Lower operations burden, but less useful for container, ECS, Linux, and service troubleshooting practice.
- Self-managed PostgreSQL on EC2: Useful for deep database administration, but not the goal. RDS is recommended for managed production patterns.
- EventBridge instead of SQS: Useful for event routing, but SQS is simpler and better for queue backlog, duplicate delivery, DLQ, and worker failure scenarios.
- CloudWatch only instead of Prometheus/Grafana: Simpler and more AWS-native, but Prometheus/Grafana add application metric and dashboard experience.
