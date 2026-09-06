# Workload IAM Module

This module creates the ECS workload IAM boundary for the API and worker services.

## Role Model

The module creates four roles:

- API ECS execution role.
- API application task role.
- Worker ECS execution role.
- Worker application task role.

Execution roles are used by the ECS/Fargate platform to pull images, write logs, and retrieve injected secrets. Task roles are exposed to application code for application-level AWS API calls.

## Trust Policy

All roles trust only `ecs-tasks.amazonaws.com` through `sts:AssumeRole`.

## Permission Model

The API execution role can pull API and Nginx images, write API and Nginx logs, and retrieve the RDS-managed secret for ECS secret injection.

The API task role can only send messages to the main SQS job queue.

The worker execution role can pull the worker image, write worker logs, and retrieve the RDS-managed secret for ECS secret injection.

The worker task role can receive, delete, change visibility for, and inspect attributes of messages on the main SQS queue. It can also put and get report objects under the configured artifact object prefix.

## Explicit Non-Goals

This module does not create ECS task definitions, ECS services, log groups, ECR repositories, Secrets Manager secrets, KMS keys, IAM database authentication, or GitHub deployment permissions.

The application task roles do not receive Secrets Manager permissions. Database credentials are intended to be injected by ECS at task start.
