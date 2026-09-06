# ECS Module

This module creates the Fargate-only runtime layer for the API, Nginx, worker, and one-off migration task definition.

## Cluster

The module creates one ECS cluster. It uses Fargate tasks only; it does not create EC2 capacity, launch templates, Auto Scaling Groups, or ECS container instances.

Container Insights is configurable and defaults to `enhanced`. Enhanced observability emits additional CloudWatch telemetry and has monitoring cost.

## Task Model

All task definitions use:

- `requires_compatibilities = ["FARGATE"]`
- `network_mode = "awsvpc"`
- Linux `X86_64`
- immutable image digest inputs

The API task contains two essential business containers plus a non-essential ADOT collector sidecar:

- `api`, listening internally on port 8000
- `nginx`, listening on port 80
- `adot-collector`, receiving localhost OTLP traces and scraping FastAPI `/metrics`

Nginx proxies to `127.0.0.1:8000` because both containers run in the same ECS task network namespace. The ALB targets only the Nginx container on port 80.

The worker task contains one essential worker container plus a non-essential ADOT collector sidecar, no inbound ports, and no load balancer integration. The worker exposes Prometheus metrics on `127.0.0.1:9464` for same-task scraping only.

The worker container uses `stopTimeout = 120` so SIGTERM-driven shutdown has the maximum Fargate grace window currently supported. This does not guarantee job completion; SQS visibility, database leases, and fencing remain the durable recovery model.

ADOT collectors are intentionally non-essential. Telemetry export failure must not stop API request handling, outbox dispatch, SQS processing, or artifact writes.

Collector configuration is supplied through non-secret `AOT_CONFIG_CONTENT`. Metrics are exported to AMP by Prometheus remote write with SigV4 authentication from the task role. Traces are exported to X-Ray. Structured container logs still use ECS `awslogs`; logs are not duplicated through OTLP.

The migration task definition uses the API image with `python -m application.migrations`. It is not a service.

## Secrets

Database username and password are injected from the RDS-managed Secrets Manager secret using JSON keys:

- `username`
- `password`

The task execution roles retrieve the secret for ECS injection. Application task roles do not receive Secrets Manager permissions.

Linux Fargate platform version 1.4.0 or later is required for Secrets Manager JSON-key injection.

## Logging

The module creates CloudWatch log groups for API, Nginx, and worker with finite retention. Log groups use CloudWatch service-managed encryption. ECS does not auto-create log groups.

The migration task writes to the API log group with a distinct `migration` stream prefix.

## Non-Goals

This module does not create IAM roles, ECR repositories, ALB resources, security groups, autoscaling policies, ECS Exec permissions, KMS keys, FireLens, dashboards, alarms, GitHub deployment workflows, staging, or production.

When Application Auto Scaling is attached by a separate module, ECS service `desired_count` is ignored after creation so Terraform does not fight runtime scaling decisions. Terraform still sets initial service size and scaling bounds are owned outside this module.
