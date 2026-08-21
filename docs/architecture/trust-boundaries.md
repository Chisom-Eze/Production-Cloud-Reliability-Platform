# Trust Boundaries

## What We Are Building

The initial trust-boundary model for the five-hour AWS Production Cloud Reliability Platform.

## Why It Exists In Production

Trust boundaries show where authentication, authorization, network controls, encryption, and audit evidence matter. They help explain how the platform limits blast radius when something fails or is compromised.

## Boundary 1: Internet To Public AWS Edge

Crossing:

- Public clients resolve DNS through Route 53 and send traffic to the ALB.

Controls:

- Public ALB listener.
- TLS termination where configured.
- Optional WAF where practical.
- Security group allowing only intended inbound ports.

Risk mitigated:

- Unrestricted public access to private compute and data services.
- Basic exposure to unwanted traffic patterns.

## Boundary 2: ALB To ECS API Task

Crossing:

- ALB forwards requests to Nginx in API tasks running in private subnets.

Controls:

- API task security group only allows inbound traffic from ALB security group.
- ALB target group health checks.
- ECS service desired count and deployment health settings.

Risk mitigated:

- Direct public access to containers.
- Serving traffic to unhealthy tasks.

## Boundary 3: Nginx Sidecar To FastAPI Container

Crossing:

- Nginx reverse proxies to the FastAPI container inside the same ECS task.

Controls:

- FastAPI should not be directly exposed to the ALB.
- Nginx owns access logging, timeout handling, security headers, and upstream health behavior.
- Nginx sidecar scales with API tasks so it is not a singleton.

Risk mitigated:

- Missing reverse proxy controls.
- Unclear upstream timeout behavior.
- Centralized proxy becoming a single point of failure.

## Boundary 4: ECS API And Worker To RDS

Crossing:

- API and worker connect to PostgreSQL.

Controls:

- RDS in private database subnets.
- RDS security group only allows PostgreSQL from approved ECS security groups.
- Credentials stored in Secrets Manager.
- Encryption at rest.

Risk mitigated:

- Public database exposure.
- Credential leakage.
- Unauthorized network access to data.

## Boundary 5: ECS API And Worker To SQS

Crossing:

- API sends job messages.
- Worker receives and deletes job messages.

Controls:

- IAM task roles with least-privilege SQS permissions.
- DLQ for failed messages.
- Visibility timeout and max receive count configured deliberately.

Risk mitigated:

- Unapproved producers or consumers.
- Message loss from unsafe delete behavior.
- Infinite retry loops without isolation.

## Boundary 6: ECS API And Worker To S3

Crossing:

- API or worker writes and reads durable artifacts in S3.
- PostgreSQL stores object metadata and references.

Controls:

- IAM task roles scoped to the required bucket and object prefixes.
- S3 public access blocked.
- Bucket encryption enabled.
- Bucket ownership and lifecycle policies defined where practical.

Risk mitigated:

- Public object exposure.
- Over-broad object access.
- Confusing transactional state with durable object storage.
- Orphaned S3 objects after partial workflow failure.

## Boundary 7: GitHub Actions To AWS

Crossing:

- GitHub Actions assumes an AWS deployment role using OIDC.

Controls:

- IAM trust policy scoped to GitHub OIDC provider.
- Conditions scoped to repository, branch, and environment.
- No long-lived AWS keys.
- Deployment role permissions limited to required services and environment.

Risk mitigated:

- Stolen static cloud credentials.
- Unauthorized deployments from untrusted repositories or branches.

## Boundary 8: Application To Secrets Manager

Crossing:

- ECS tasks retrieve runtime secrets.

Controls:

- Task role allows access only to required secrets.
- Secret values are not committed to source.
- Secrets are not baked into Docker images.

Risk mitigated:

- Source-code secret leaks.
- Over-broad secret access across services or environments.

## Boundary 9: Observability Access

Crossing:

- Operators inspect CloudWatch, Prometheus, and Grafana.

Controls:

- CloudWatch access controlled through AWS IAM.
- Grafana access must not be publicly unauthenticated.
- Prometheus scraping endpoint exposure should be limited to intended network paths.

Risk mitigated:

- Metrics/log data exposure.
- Dashboard access without authentication.
- Operational data becoming a reconnaissance surface.

## Boundary 10: Operators To AWS Control Plane

Crossing:

- Engineers inspect logs, metrics, alarms, deployments, and resources.

Controls:

- IAM access for humans should be separate from workload roles.
- CloudTrail records AWS API activity.
- Least-privilege read or break-glass permissions should be defined later.

Risk mitigated:

- Untraceable administrative changes.
- Excessive production access.
- Configuration drift.
