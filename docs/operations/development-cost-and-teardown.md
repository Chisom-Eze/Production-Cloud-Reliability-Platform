# Development Cost And Teardown

This runbook closes Stage N for the development environment cost operating model.

It is documentation only. It does not create AWS resources, deploy infrastructure, destroy infrastructure, or add an automated cost-control mechanism.

## Operating Model

The development environment is intentionally ephemeral:

```text
deploy
  -> verify
  -> monitor
  -> test, fail, and improve
  -> redeploy as required
  -> destroy when the deployable unit has been proven
```

Development is not intended to run indefinitely as a low-traffic production clone. It exists to prove the deployable unit, validate observability, practice failure recovery, and capture engineering evidence before promotion work continues.

Cost control is handled through small capacity choices, finite retention, lifecycle policies, and deliberate teardown after validation. Security boundaries are still production-grade; development may be cheaper, but it should not rely on intentionally broad trust.

## Account-Level Budget Alert

The operator already has an AWS Budget alert configured at the AWS account level.

That budget is an external spend alert, not a Terraform-managed resource in this repository. This project does not create:

* `aws_budgets_budget`
* a separate FinOps Terraform root
* Cost Anomaly Detection infrastructure
* automated budget-triggered destruction
* automated TTL destruction
* new paid services solely for Stage N

A cost alarm should trigger human review. It must not trigger automatic destructive action by itself.

## Existing Cost Boundaries

The current development design already includes these cost boundaries:

| Area | Development choice | Cost effect |
| --- | --- | --- |
| NAT | One NAT Gateway | Lower fixed cost than per-AZ NAT |
| API ECS service | desired/min `1`, max `4` | Keeps baseline small and caps scale-out |
| Worker ECS service | desired/min `1`, max `4` | Keeps outbox processing available while bounding scale-out |
| Fargate tasks | Small API, worker, migration, and ADOT task sizes | Limits task-hour cost |
| RDS | `db.t4g.micro` | Small managed database baseline |
| RDS storage | 20 GiB initial, 100 GiB maximum | Bounded autoscaling storage exposure |
| RDS availability | Single-AZ | Lower development cost than Multi-AZ |
| RDS backups | 7-day managed backup retention | Finite backup retention |
| CloudWatch logs | Finite retention | Avoids indefinite log storage growth |
| S3 artifacts | Lifecycle controls | Cleans incomplete multipart uploads and old noncurrent versions |
| ECR | Untagged image cleanup | Limits stale image storage |
| VPC endpoints | S3 Gateway Endpoint only | Avoids paid interface endpoint hourly charges |
| Encryption | Service-managed encryption where appropriate | Avoids customer-managed KMS cost purely for scanner compliance |

## Fixed Or Idle-Cost Resources

These resources can create cost even with little or no traffic:

* NAT Gateway and associated Elastic IP
* Application Load Balancer
* ECS tasks kept at desired count `1`
* RDS instance, allocated storage, backups, and snapshots
* CloudWatch alarms, dashboards, custom metrics, logs, and Container Insights telemetry
* Amazon Managed Service for Prometheus workspace
* Amazon Managed Grafana workspace
* AWS WAF web ACL and logging
* Route 53 hosted zone and health/DNS query charges
* CloudTrail audit bucket storage and requests
* ECR repository image storage
* S3 artifact and log storage
* Secrets Manager secrets when application secrets are provisioned

## Usage-Sensitive Resources

These costs grow with traffic, data volume, telemetry volume, or operational activity:

* NAT data processing for non-S3 private-subnet egress
* ALB request volume and LCU dimensions
* WAF inspected requests and log volume
* Fargate task-hours when autoscaling increases desired count
* SQS requests, long polling, retries, and DLQ storage
* S3 requests, artifact bytes, object versions, and lifecycle transitions
* ECR image pulls, image scans, and stored image bytes
* CloudWatch log ingestion, metric ingestion, alarms, dashboards, and Logs Insights queries
* AMP metric samples, active series cardinality, and queries
* X-Ray trace volume
* RDS storage growth, I/O, backup storage, and exported logs
* Route 53 DNS queries

## Resources Intentionally Retained Despite Cost

Some cost-bearing resources are intentionally part of the first controlled development deployment:

* AMP remains because ADOT metrics are wired to the observability design and must be validated.
* AMG remains because dashboard access is part of the observability operating model.
* One NAT Gateway remains because non-S3 HTTPS egress is still required until endpoint economics and security requirements justify interface endpoints.
* Worker desired count `1` remains because outbox dispatch and queue processing should be continuously available during validation.
* CloudTrail audit evidence remains because governance evidence should not be removed casually.
* Immutable ECR release images may remain so the exact deployed image digest can be promoted, rolled back, or investigated later.
* Final RDS snapshots may remain after destroy so database state can be recovered or inspected.
* Terraform remote state must remain because it is the source of infrastructure ownership and state lineage.

## Safe Teardown Procedure

Teardown is a deliberate operator action after the development deployable unit has been proven. It should not be triggered automatically by a budget alarm alone.

Before teardown:

1. Confirm the deployment, monitoring checks, and failure drills have produced the evidence needed for the stage.
2. Confirm no incident, audit review, or debugging session still needs the live environment.
3. Record important runtime evidence, including ALB DNS name, application URL, ECS service/task state, deployed image digests, RDS snapshot expectations, alarm state, and relevant dashboard screenshots or exports.
4. Confirm the intended Terraform root is the development runtime root, not bootstrap or shared governance roots.
5. Review DNS records before removing the runtime edge. Do not leave user-facing DNS pointing at a destroyed ALB unless that is an intentional maintenance state.

Destroyable application/runtime infrastructure can include:

* development VPC, subnets, routes, route tables, Internet gateway, NAT gateway, and S3 Gateway Endpoint
* development security groups
* development ALB, target groups, listeners, and ALB log storage owned by the development root
* development ECS cluster, services, task definitions, autoscaling policies, and workload IAM resources
* development RDS instance, while preserving any required final snapshot
* development SQS queue and DLQ
* development S3 artifact bucket when object-retention and evidence requirements have been reviewed
* development WAF resources and logging
* development CloudWatch alarms, dashboards, and log groups
* development AMP, AMG, ADOT, and X-Ray resources owned by the development root
* development ACM and Route 53 records after DNS impact is reviewed

Resources and data that must not be casually destroyed include:

* Terraform remote-state bucket, state objects, and lockfile behavior
* bootstrap GitHub OIDC provider and deployment role
* shared ECR repositories and immutable release images that are still needed for promotion, rollback, or audit
* shared CloudTrail trail, audit bucket, EventBridge detections, and security SNS topic
* CloudTrail logs and audit evidence
* final RDS snapshots required for recovery or evidence
* DNS hosted zones and account-level DNS ownership resources
* the external AWS Budget alert

During teardown:

1. Use the approved authenticated deployment process for the development runtime root when it exists.
2. Keep Terraform state remote and locked.
3. Do not destroy bootstrap state resources as part of runtime teardown.
4. Do not destroy shared ECR or shared security-audit roots unless a separate governance review explicitly approves it.
5. Preserve final RDS snapshots unless the operator deliberately decides they are no longer needed.
6. Preserve CloudTrail and audit evidence.

## Post-Destroy Verification Checklist

After teardown, verify:

* no development ECS services or running tasks remain
* no development ALB remains unless intentionally retained
* no development NAT Gateway or unattached Elastic IP remains unexpectedly
* no development RDS instance remains, and any final snapshot is identified
* no development SQS queue or DLQ remains unless intentionally retained
* no development artifact bucket remains unless retained for evidence or cleanup
* no development WAF web ACL or logging resources remain unless intentionally retained
* no development AMP, AMG, ADOT, X-Ray, CloudWatch dashboard, alarm, or log group remains unless intentionally retained
* DNS records do not point users to a destroyed or unintended endpoint
* Terraform remote state remains accessible and versioned
* ECR release images required for audit, rollback, or promotion still exist
* CloudTrail remains enabled and audit logs remain protected
* the external AWS Budget alert remains active
* tagged resource review does not show unexpected live development resources

## Deferred FinOps Improvements

Deferred FinOps work should be driven by measured cost, risk, and operational need:

* Terraform-managed account budget only if budget ownership moves into this repository
* Cost Anomaly Detection after a stable spend baseline exists
* explicit teardown workflow with human approval gates
* scheduled reminders or TTL reporting that never destroys automatically
* interface endpoint cost comparison for ECR, CloudWatch Logs, Secrets Manager, SQS, AMP, and X-Ray
* more granular ECR lifecycle policies for release, candidate, and untagged image classes
* artifact retention policy for current report objects, not only noncurrent versions and multipart uploads
* audit bucket retention, Object Lock, and customer-managed KMS only when governance requires them
* cost dashboarding once real deployment and telemetry volume exist
* production-specific NAT, Multi-AZ RDS, backup, and observability cost modeling

