# ECS Autoscaling Module

This module attaches AWS Application Auto Scaling to existing ECS services.

## Ownership

Terraform creates the scalable targets and target-tracking policies. Application Auto Scaling owns runtime `DesiredCount` after service creation. The ECS service module must ignore `desired_count` drift so Terraform does not fight scaling decisions.

## API Scaling

The API service scales with target tracking on:

- `ECSServiceAverageCPUUtilization`
- `ECSServiceAverageMemoryUtilization`

With multiple target-tracking policies, AWS scales out if any policy requires scale out. Scale in occurs only when all scale-in-enabled policies agree.

ALB request-count-per-target scaling is intentionally deferred until load testing establishes a defensible per-task throughput target.

## Worker Scaling

The worker service scales on SQS backlog per running worker task:

```text
ApproximateNumberOfMessagesVisible / RunningTaskCount
```

The SQS metric comes from `AWS/SQS` using the real queue name. Running task count comes from `ECS/ContainerInsights` using the real cluster and worker service names.

Worker minimum capacity must remain at least `1` because the worker owns both transactional-outbox dispatch and SQS consumption. Scaling to zero would allow API requests to keep committing outbox rows with no active dispatcher.

## Cooldowns

Default scale-out cooldown is 60 seconds. Default scale-in cooldown is 300 seconds. Scale-in is intentionally conservative because workers may hold leases, process side effects, and have in-flight SQS messages.

## Non-Goals

This module does not create IAM permissions, CloudWatch dashboards, general operational alarms, Prometheus, Grafana, OpenTelemetry, ECS task scale-in protection, VPC endpoints, KMS keys, or deployment workflows.
