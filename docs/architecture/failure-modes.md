# Major Failure Modes

## What We Are Building

The initial list of high-value failures the platform should be able to demonstrate, detect, troubleshoot, and recover from.

## Why It Exists In Production

Production reliability depends on understanding how systems fail. These failure modes guide what to monitor, what runbooks to write, and what interview explanations the project must support.

## 1. ALB Or Nginx 502

Possible causes:

- Nginx upstream points to the wrong FastAPI port.
- FastAPI container is not listening.
- API task is unhealthy.
- ALB target group points to the wrong container or port.
- Nginx configuration fails to load.

Detection:

- ALB 5xx metrics.
- Target group unhealthy host count.
- ECS task restart events.
- Nginx error logs.
- API container logs.

Recovery:

- Roll back the bad deployment.
- Fix Nginx upstream, container port, or target group configuration.
- Restore missing dependency or startup configuration.

## 2. ALB Or Nginx 504

Possible causes:

- FastAPI request exceeds Nginx or ALB timeout.
- Database query is slow.
- Worker or downstream dependency blocks request path.
- Nginx proxy timeout is too aggressive.

Detection:

- ALB latency and 5xx metrics.
- Nginx request time/upstream time logs.
- API latency metrics.
- RDS CPU, connection, and query evidence.

Recovery:

- Roll back slow code.
- Tune Nginx/ALB timeouts only when justified.
- Fix slow query or dependency.
- Move long-running work to SQS.

## 3. Queue Backlog And DLQ Growth

Possible causes:

- Worker service is stopped or under-scaled.
- Worker cannot read SQS due to IAM failure.
- Worker fails while processing messages.
- Database or S3 dependency is degraded.
- Poison messages repeatedly fail.

Detection:

- SQS approximate visible messages.
- SQS age of oldest message.
- DLQ message count.
- Worker job failure metrics.
- Worker error logs.

Recovery:

- Restore or scale worker service.
- Fix IAM or dependency failure.
- Inspect DLQ messages.
- Re-drive messages only after root cause is understood.

## 4. Duplicate SQS Delivery

Possible causes:

- Worker processes successfully but fails before deleting the message.
- Visibility timeout expires during processing.
- AWS standard SQS at-least-once delivery behavior.

Detection:

- Repeated job IDs in worker logs.
- Job attempts greater than expected.
- Duplicate S3 object upload attempts.

Recovery:

- Use idempotent job state transitions.
- Use deterministic S3 object keys tied to job IDs.
- Delete SQS messages only after durable completion.
- Tune visibility timeout.

## 5. RDS Degradation

Possible causes:

- Inefficient query.
- Missing index.
- Too many connections.
- Long-running transaction.
- RDS CPU, storage, or I/O pressure.

Detection:

- RDS CPU and connection metrics.
- API latency and 5xx metrics.
- PostgreSQL logs.
- `EXPLAIN` and `EXPLAIN ANALYZE`.

Recovery:

- Roll back bad query.
- Add or fix index in a controlled migration.
- Reduce connection pressure.
- Scale RDS where justified.

## 6. S3 Write Failure

Possible causes:

- Task role lacks S3 permission.
- Bucket policy denies write.
- Wrong bucket or key prefix.
- S3 service or network path issue.

Detection:

- Worker error logs.
- Failed job state.
- CloudTrail denied S3 events.
- Application metrics for worker failures.

Recovery:

- Fix IAM policy, bucket policy, or configuration.
- Retry failed job if safe.
- Preserve failed state for diagnosis.

## 7. S3/PostgreSQL Partial Failure

Possible causes:

- S3 upload succeeds but PostgreSQL metadata update fails.
- PostgreSQL update succeeds but SQS message deletion fails.
- Worker crashes between object upload and job completion.

Detection:

- S3 object exists without matching PostgreSQL metadata.
- Duplicate processing attempts for the same job ID.
- Job remains processing or failed with existing S3 object.

Recovery:

- Reconcile S3 objects against PostgreSQL metadata.
- Use deterministic object keys for idempotent overwrite or existence checks.
- Let duplicate delivery complete idempotently.
- Document cleanup of orphaned artifacts.

## 8. Failed Deployment

Possible causes:

- Bad image.
- Broken startup command.
- Missing environment variable.
- Nginx config error.
- Migration or schema mismatch.
- Health checks fail after deployment.

Detection:

- GitHub Actions failure.
- ECS deployment circuit breaker or service events.
- ALB unhealthy target count.
- Smoke test failure.

Recovery:

- Revert or roll back to last known good image.
- Re-run deployment after fixing configuration.
- Verify smoke tests and service health.

## 9. IAM AccessDenied

Possible causes:

- Task role lacks required SQS, S3, Secrets Manager, or CloudWatch permission.
- Deployment role lacks infrastructure permission.
- Trust policy does not match GitHub OIDC subject.
- Resource ARN is too narrow or incorrect.

Detection:

- Application logs with AWS `AccessDenied` error.
- CloudTrail denied API events.
- GitHub Actions deployment logs.

Recovery:

- Identify denied action and resource.
- Update least-privilege policy.
- Re-deploy and verify only the required permission was added.

## 10. Secrets Manager Access Failure

Possible causes:

- Secret missing or rotated incorrectly.
- ECS task cannot retrieve secret.
- Task role lacks `secretsmanager:GetSecretValue`.
- Environment-specific secret ARN is wrong.

Detection:

- API startup failure.
- Readiness endpoint failure.
- ECS stopped task reason.
- CloudTrail and Secrets Manager access logs.

Recovery:

- Restore secret value or ARN.
- Fix task role permission.
- Re-deploy service.

## 11. Linux Resource Pressure

Possible causes:

- CPU saturation.
- Memory exhaustion.
- Disk pressure.
- Too many open connections.
- Runaway process.

Detection:

- ECS CPU and memory metrics.
- Container logs.
- Local diagnostic scripts using `ps`, `top`, `df`, `du`, `free`, and `ss`.

Recovery:

- Stop or roll back bad workload.
- Adjust CPU or memory allocation.
- Fix resource leak.
- Add alarms or limits to catch recurrence.

## 12. Cost Spike

Possible causes:

- Excessive CloudWatch log volume.
- NAT Gateway data processing.
- Over-sized RDS instance.
- Runaway ECS scaling.
- S3 storage or data transfer growth.
- Overbuilt Prometheus/Grafana hosting.

Detection:

- AWS billing alerts.
- Cost Explorer.
- CloudWatch usage metrics where available.

Recovery:

- Reduce log verbosity.
- Right-size services.
- Review NAT usage.
- Apply lifecycle policies to S3.
- Keep observability deployment small for the initial project.
