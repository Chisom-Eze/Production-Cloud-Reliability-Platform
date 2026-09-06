# Terraform Infrastructure

This directory separates Terraform roots from reusable modules so resource ownership, state boundaries, and environment blast radius stay explicit.

## Directory Structure

```text
infrastructure/
|-- bootstrap/
|-- modules/
|   |-- acm-dns/
|   |-- alb/
|   |-- ecr/
|   |-- rds/
|   |-- security-groups/
|   |-- s3-artifacts/
|   |-- sqs/
|   |-- vpc-endpoints/
|   |-- waf/
|   |-- workload-iam/
|   `-- vpc/
|-- shared/
|   |-- container-registry/
|   `-- security-audit/
`-- environments/
    |-- development/
    |-- staging/
    `-- production/
```

## Roots And Modules

A Terraform root decides what resources are created and owns a remote state file. A reusable module defines how a resource pattern is built.

Modules do not contain backend blocks, backend configuration, account IDs, or development/staging/production assumptions. Root modules provide inputs and own state.

## State Ownership Matrix

| Root | Responsibility | State key |
| --- | --- | --- |
| `bootstrap` | Foundational state bucket, S3 backend controls, GitHub OIDC provider, GitHub development deployment role | Existing key, unchanged |
| `shared/container-registry` | Shared ECR repositories and GitHub ECR publishing policy attachment | `shared/container-registry/terraform.tfstate` |
| `shared/security-audit` | Account-level CloudTrail audit bucket, multi-Region trail, targeted security EventBridge rules, and security SNS topic | `shared/security-audit/terraform.tfstate` |
| `environments/development` | Development runtime infrastructure: VPC, security groups, private PostgreSQL RDS foundation, SQS job queue, S3 artifact storage, ECS workload IAM, public ALB edge, and WAF protection | `environments/development/terraform.tfstate` |
| `environments/staging` | Future staging runtime infrastructure | `environments/staging/terraform.tfstate` |
| `environments/production` | Future production runtime infrastructure | `environments/production/terraform.tfstate` |

## Bootstrap Boundary

Bootstrap is kept small and stable because it owns foundational resources that other Terraform roots and delivery systems depend on. Existing bootstrap resources are not moved into modules because that would change Terraform resource addresses and require a controlled state migration.

Application infrastructure does not belong in bootstrap. ECR belongs to shared infrastructure because one build should be pushed once, captured by digest, and promoted through development, staging, and production.

## Environment Strategy

This project does not use Terraform workspaces for development, staging, or production. Each environment has an explicit root and independent state file so a change to development state cannot modify staging or production state.

Each environment can be planned, applied, locked, reviewed, and protected independently.

## Environment Hardening

Development should be cost-conscious and optimized for fast feedback while remaining secure and observable. Staging should be production-like with smaller capacity where appropriate. Production should use the strongest availability, retention, deletion protection, alerting, promotion, rollback, and change-management controls justified by the system.

Hardening differences should be expressed later through root-level module inputs such as `enable_deletion_protection`, `multi_az`, `log_retention_days`, `desired_count`, and `backup_retention_days`. Generic modules should not scatter environment-name conditionals unless technically necessary.

## Cross-Root Dependencies

One AWS resource must have one Terraform owner. Roots may consume stable identifiers through variables, data lookups, or deliberate output contracts, but they must not duplicate resource declarations.

The shared container registry root attaches a separate customer-managed ECR publishing policy to the existing GitHub development deployment role by role name. Bootstrap continues to own the IAM role and its OIDC trust policy. The shared root owns only the ECR publishing policy and attachment.

## Build Once, Promote Same Digest

The intended delivery model is:

```text
commit
  -> security gates
  -> build once
  -> push to ECR
  -> capture digest
  -> development
  -> staging
  -> production
```

The same image digest should move through environments. Rollback means redeploying a previous known-good digest, not rebuilding or relying on a mutable tag.

## Adding Future Modules

Create new modules only when the resource pattern is actually implemented. Do not create placeholder modules for ECS or observability before those stages define the real interface.

## Development Network Foundation

The development root owns the first runtime network:

- VPC CIDR `10.10.0.0/16`
- Public subnets for future ALB resources
- Application-private subnets for future ECS/Fargate API and worker services
- Database-private subnets for RDS
- One NAT Gateway for development application-private egress
- No default Internet or NAT route from database-private subnets

The reusable VPC module accepts a `nat_gateway_strategy` input instead of checking the environment name internally. Development passes `single`; staging and production can later pass `per_az` without forking the module.

## Stage 4B Security Group Hardening

Stage 4B belongs to the `environments/development` root and uses the reusable `modules/security-groups` module.

Security decisions:

- Internet ingress terminates only at the future ALB security group on TCP 80 and TCP 443.
- TCP 80 is retained so a future ALB listener can redirect HTTP to HTTPS.
- TCP 443 is present for future TLS termination at the ALB.
- API ECS tasks accept TCP 80 only from the ALB security group.
- Worker ECS tasks have no inbound application traffic.
- RDS accepts TCP 5432 only from API and worker security groups.
- FastAPI TCP 8000 is not exposed through network security groups.
- Workload database access uses security-group references, not VPC or subnet CIDR trust.

Cost decisions:

- Development still uses one NAT Gateway from Stage 4A for lower cost.
- Security posture is not weakened for development. Capacity can be cheaper, but known security boundaries remain production-grade.

Production-hardening decisions:

- No all-port, all-protocol egress is allowed from API or worker workloads.
- API and worker egress is limited to TCP 443 for HTTPS-based AWS APIs and permitted external dependencies through NAT, plus explicit TCP 5432 to RDS.
- RDS has no broad egress rule; security groups are stateful and database response traffic does not require allow-all egress.
- No IPv6 `::/0` rules are added because the current VPC design is IPv4-only.
- No DNS rules are added because this stage does not require compensating rules for Amazon VPC-provided DNS behavior.

Intentional trade-offs:

- API and worker still have TCP 443 egress to `0.0.0.0/0` because initial AWS API and external dependency access flows through NAT. Later VPC endpoint stages can reduce NAT dependence for ECR, S3, CloudWatch Logs, Secrets Manager, and related AWS services.

Deferred components:

- ECS services, Secrets Manager resources, CloudWatch alarms, and VPC endpoints remain deferred. RDS is implemented in Stage 4C, SQS is implemented in Stage 4D, S3 artifact storage is implemented in Stage 4E, workload IAM is implemented in Stage 4F, the ALB/ACM public edge is implemented in Stage 4G, and WAF protection is implemented in Stage 4H.

## Stage 4C RDS Foundation

Stage implemented:

- Stage 4C adds the private PostgreSQL RDS foundation for the development runtime environment.

Ownership/root:

- The reusable implementation lives in `modules/rds`.
- The development deployment decision lives in `environments/development/database.tf`.
- The development root owns RDS state under `environments/development/terraform.tfstate`.
- Bootstrap, shared ECR, VPC module, and security-group module resources are unchanged.

Security decisions:

- The database is private-only with `publicly_accessible = false`.
- The DB subnet group uses only database-private subnets from the VPC module.
- The DB instance attaches only the RDS security group produced by the security-group module.
- API and worker reach PostgreSQL by security-group reference on TCP 5432.
- No database password is stored in Terraform input variables, tfvars, or outputs.
- RDS manages the master user password through `manage_master_user_password = true`.
- The managed secret ARN is output as sensitive metadata for later application wiring.

Cost decisions:

- Development uses `db.t4g.micro`, Single-AZ, 20 GiB gp3 storage, and 100 GiB max allocated storage.
- Development log retention is 7 days.
- No customer-managed KMS key is created in this stage.
- No RDS Proxy, read replica, or AWS Backup plan is created in this stage.

Production-hardening decisions:

- Storage encryption is enabled from the first database implementation.
- Automated backups are enabled with 7-day retention in development.
- Final snapshots are required on destroy because `skip_final_snapshot = false`.
- `copy_tags_to_snapshot = true` preserves operational tags on snapshots.
- Major version upgrades are not automatic.
- Minor version upgrades are allowed.
- Changes are not applied immediately by default; they wait for the maintenance window.
- PostgreSQL and upgrade logs export to CloudWatch Logs.
- Standard RDS CloudWatch metrics remain available through the managed RDS service integration.
- Enhanced Monitoring is enabled through an RDS service-assumable IAM role using the AWS managed `AmazonRDSEnhancedMonitoringRole` policy.
- Performance Insights is exposed as a module input but disabled in development until the exact instance class, provider behavior, and cost posture are confirmed before deployment.

Intentional trade-offs:

- Development is Single-AZ to control cost. Production should use Multi-AZ when the availability target requires managed failover.
- Development disables deletion protection so lab teardown remains possible. Production should enable deletion protection.
- Service-managed encryption is used now to avoid premature customer-managed KMS design. A CMK can be introduced later only with a key ownership, rotation, access, and recovery model.

Deferred components:

- RDS Proxy is deferred until connection pooling or failover behavior justifies it.
- Read replicas are deferred until read scaling or reporting workload requirements exist.
- AWS Backup is deferred because native RDS automated backups meet the current 7-day managed-backup requirement.
- Secrets Manager access policies for ECS are deferred until ECS task roles are implemented.
- Database alarms are deferred until the CloudWatch alarm stage defines thresholds and notification routing.

## Stage 4D SQS Job Queue And DLQ

Stage implemented:

- Stage 4D adds the hardened asynchronous job queue foundation for the future API and worker architecture.

Ownership/root:

- The reusable implementation lives in `modules/sqs`.
- The development deployment decision lives in `environments/development/queue.tf`.
- The development root owns SQS state under `environments/development/terraform.tfstate`.
- Bootstrap, shared ECR, VPC, security groups, and RDS resources are unchanged.

Standard queue decision:

- The application uses an SQS Standard queue, not FIFO.
- Standard queue throughput and scaling match asynchronous job processing.
- The application must tolerate at-least-once delivery, duplicates, and possible reordering.

Failure and redrive decisions:

- Main queue visibility timeout is 60 seconds.
- Worker processing must finish or extend visibility before 60 seconds to avoid duplicate concurrent processing.
- `maxReceiveCount = 3`.
- Failed messages move to the DLQ after three unsuccessful receive/process attempts.
- Main queue retention is 4 days.
- DLQ retention is 14 days so failed jobs have a longer investigation and replay window.
- Delivery delay is 0 because there is no current business requirement for delayed processing.

Long polling:

- `receive_wait_time_seconds = 20` reduces empty receives, receive API calls, and worker polling cost.

Security decisions:

- Both queues use SQS-managed server-side encryption through `sqs_managed_sse_enabled = true`.
- No customer-managed KMS key, alias, or `kms_master_key_id` is created for SQS in this stage.
- Queue resource policies deny requests when `aws:SecureTransport = false`.
- Queue resource policies do not include public Allow statements or cross-account access.
- The DLQ redrive allow policy uses `redrivePermission = "byQueue"` and allows only the intended main queue ARN.

Future API/worker IAM contract:

- The future API task role should receive only producer permissions such as `sqs:SendMessage`, plus `sqs:GetQueueUrl` or `sqs:GetQueueAttributes` only if the application actually requires them.
- The future worker task role should receive consumer permissions such as `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:ChangeMessageVisibility`, and `sqs:GetQueueAttributes` only if required.
- Neither role should receive SQS administrative actions.
- Identity-based workload permissions are deferred to the IAM/ECS stage because the task roles do not exist yet.

Idempotency requirement:

- SQS Standard is at-least-once. Infrastructure cannot eliminate duplicate deliveries or duplicate side effects.
- Worker processing must be idempotent and coordinated with durable PostgreSQL job state.

Dual-write/outbox risk:

- The API may need to commit a job row in PostgreSQL and send a message to SQS.
- A failure between the database commit and SQS send can leave persisted work without queued delivery.
- SQS retries do not solve this dual-write gap.
- A transactional outbox should be evaluated or implemented at the application layer before final production release.

Observability integration:

- SQS native CloudWatch metrics will feed the later observability stage.
- Important future metrics include `ApproximateNumberOfMessagesVisible`, `ApproximateNumberOfMessagesNotVisible`, `ApproximateAgeOfOldestMessage`, `NumberOfMessagesSent`, `NumberOfMessagesReceived`, and DLQ message count.
- Alarms and SNS routing are not created here because alert destinations belong to the observability stage.

Cost decisions:

- SQS is request-priced and has no always-on queue compute charge.
- Long polling reduces unnecessary receive calls.
- DLQ retention increases investigation value with low operational complexity.
- SQS-managed encryption avoids customer-managed KMS key overhead.

Production-hardening posture:

- The queue is encrypted, TLS-guarded, redrive-protected, and explicit about retry/retention behavior from the first implementation.
- Development keeps the same security posture as production while using modest retention and no additional endpoint infrastructure yet.

## Stage 4E S3 Artifact Storage

Stage implemented:

- Stage 4E adds private durable S3 storage for application-generated artifacts.

Ownership/root:

- The reusable implementation lives in `modules/s3-artifacts`.
- The development deployment decision lives in `environments/development/storage.tf`.
- The development root owns artifact bucket state under `environments/development/terraform.tfstate`.
- Bootstrap, shared ECR, VPC, security groups, RDS, and SQS resources are unchanged.

Artifact contract:

- The initial generated artifact is a CSV report.
- Worker output is stored under `reports/{job_id}/{report_id}.csv`.
- PostgreSQL stores the durable object reference.
- S3 stores the artifact bytes.
- ECS/Fargate container filesystems are ephemeral and are not durable artifact storage.

Security decisions:

- The artifact bucket is private-only.
- Full S3 Public Access Block is enabled with `block_public_acls`, `ignore_public_acls`, `block_public_policy`, and `restrict_public_buckets`.
- Object ownership is `BucketOwnerEnforced`, so ACLs are disabled.
- No public-read ACL, website hosting, anonymous `GetObject`, public Allow policy, or cross-account access is created.
- A TLS-only bucket policy denies S3 actions when `aws:SecureTransport = false`.

Encryption decisions:

- S3 artifact storage uses SSE-S3 with `AES256`.
- No customer-managed KMS key or alias is created.
- The module does not set `aws:kms` or `kms_master_key_id`.
- This is distinct from RDS encryption, whose service behavior is inherently KMS-backed.

Versioning and lifecycle decisions:

- Bucket versioning is enabled as a data-protection control.
- Accidental overwrites and deletes are recoverable through prior versions and delete-marker behavior.
- Current application artifacts are not automatically expired because current-object retention is a business/data-retention decision.
- Incomplete multipart uploads are aborted after 7 days.
- Noncurrent versions expire after 30 days in development.
- Production can set longer noncurrent retention through inputs without changing module implementation.

Deletion safety:

- `force_destroy = false` prevents Terraform from silently deleting a non-empty artifact bucket.
- Teardown requires deliberate object handling before bucket destruction.

Future worker/API IAM contract:

- The future worker task role should receive only required object actions for `reports/*`, such as `s3:PutObject` and `s3:GetObject`.
- `s3:DeleteObject` should be granted only if the application implements a genuine artifact-delete workflow.
- If the API later serves report content directly, it may require `s3:GetObject` for `reports/*`.
- Bucket-level permissions such as `s3:ListBucket` should be added only if application behavior actually requires them.
- Future IAM should avoid `s3:*` and `Resource = "*"`.

Presigned URL model:

- Public bucket access is not required for artifact download.
- A future API may issue time-limited presigned S3 URLs while keeping the bucket private.
- CloudFront and application presigning logic are not implemented in this Terraform stage.

Network/S3 endpoint decision:

- S3 is a regional AWS service and the bucket does not live inside the VPC.
- Initial private application subnet access can use the NAT path.
- A future S3 Gateway VPC Endpoint should be evaluated in the network endpoint stage because it has no hourly charge, can remove S3 traffic from NAT, and improves private-service routing.
- The VPC module is not modified in this stage.

Audit/logging contract:

- S3 data-plane auditing is a centralized observability/security decision.
- Future stages should evaluate CloudTrail S3 data events, central log archive ownership, access/audit requirements, and high-volume data-event cost.
- Ordinary CloudTrail management events should not be treated as complete S3 object-level auditing.

Cost decisions:

- S3 charges for storage, requests, and data-transfer patterns.
- Versioning can increase storage usage.
- The 30-day noncurrent-version lifecycle limits indefinite version growth.
- Incomplete multipart cleanup avoids abandoned-storage waste.
- SSE-S3 avoids customer-managed KMS key cost.
- No public CDN, CloudFront distribution, or always-on compute resource is introduced in this stage.

Production-hardening contract:

- Public access controls, object ownership, encryption, TLS enforcement, versioning, lifecycle hooks, and destructive-delete safety are deployment-grade now.
- Production should mainly adjust policy values such as noncurrent-version retention, business-defined current artifact retention, and centralized audit/logging requirements.
- Production should not require rewriting the bucket security architecture.

## Stage 4F ECS Workload IAM

Stage implemented:

- Stage 4F adds deployment-grade IAM roles for the future ECS API and worker workloads.

Ownership/root:

- The reusable implementation lives in `modules/workload-iam`.
- The development deployment decision lives in `environments/development/iam.tf`.
- The development root owns workload IAM state under `environments/development/terraform.tfstate`.
- Bootstrap, shared ECR, VPC, security groups, RDS, SQS, and S3 artifact resources are unchanged.

Four-role model:

- API ECS execution role.
- API application task role.
- Worker ECS execution role.
- Worker application task role.

Execution role vs task role:

- Execution roles are used by the ECS/Fargate platform to pull ECR images, write CloudWatch Logs, and retrieve Secrets Manager values for ECS secret injection.
- Task roles are exposed to application code and contain only application-level AWS API permissions.
- The project does not attach `AmazonECSTaskExecutionRolePolicy` blindly; it uses scoped inline policies for the known ECR, logging, and secret-injection needs.

Trust model:

- All four roles trust only `ecs-tasks.amazonaws.com` through `sts:AssumeRole`.
- No role trusts EC2, Lambda, GitHub OIDC, arbitrary principals, or `"*"`.
- No instance profile is created.

API execution role:

- `ecr:GetAuthorizationToken` on `Resource = "*"`, because AWS does not support repository-scoping for that action.
- ECR pull actions only for `production-cloud-reliability-api` and `production-cloud-reliability-nginx`.
- `logs:CreateLogStream` and `logs:PutLogEvents` only for future API and Nginx log streams.
- `secretsmanager:GetSecretValue` only for the RDS-managed database secret ARN.

API task role:

- `sqs:SendMessage` only to the main jobs queue.
- No S3 permissions.
- No Secrets Manager permissions.

Worker execution role:

- `ecr:GetAuthorizationToken` on `Resource = "*"`.
- ECR pull actions only for `production-cloud-reliability-worker`.
- `logs:CreateLogStream` and `logs:PutLogEvents` only for future worker log streams.
- `secretsmanager:GetSecretValue` only for the RDS-managed database secret ARN.

Worker task role:

- `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:ChangeMessageVisibility`, and `sqs:GetQueueAttributes` only on the main jobs queue.
- `s3:PutObject` and `s3:GetObject` only on the artifact bucket `reports/*` object path.
- No `sqs:SendMessage`, SQS administrative action, S3 delete action, or bucket administrative action.

RDS secret injection model:

- RDS manages the master user password through the Stage 4C managed secret.
- ECS task definitions will later inject database credential values from the secret into containers.
- Application task roles do not receive `secretsmanager:GetSecretValue`.
- Terraform references the secret ARN, not secret plaintext.
- If the RDS-managed secret rotates, already-running ECS containers do not automatically receive the new injected value. A task restart or new ECS deployment is required.

RDS authentication model:

- The application connects to PostgreSQL with normal database credentials injected by ECS.
- IAM database authentication is not implemented.
- No `rds:*` or `rds-db:connect` permissions are granted.
- Network access remains controlled by security groups: API and worker to RDS on TCP 5432.

ECR cross-root contract:

- Shared ECR repositories are owned by `shared/container-registry`.
- The development root does not create ECR repositories.
- The development root constructs exact repository ARNs from the current AWS account, `us-east-1`, and stable repository names.
- This avoids duplicate Terraform ownership and avoids live repository lookups during static validation.

CloudWatch log contract:

- Future ECS log groups are expected at `/ecs/production-cloud-reliability/development/api`, `/ecs/production-cloud-reliability/development/nginx`, and `/ecs/production-cloud-reliability/development/worker`.
- Log groups are not created in this stage.
- IAM write permissions are scoped to future log stream ARN patterns under those log groups.

Explicitly not granted:

- No `AdministratorAccess`, `PowerUserAccess`, `AmazonS3FullAccess`, `AmazonSQSFullAccess`, `AmazonEC2ContainerRegistryFullAccess`, or `SecretsManagerReadWrite`.
- No wildcard action.
- No broad resource wildcard except the required `ecr:GetAuthorizationToken` exception.
- No customer-managed KMS key or `kms:Decrypt`.
- No runtime Secrets Manager access for application task roles.

Cost decisions:

- IAM roles and inline policies have no normal hourly infrastructure charge.
- The RDS-managed Secrets Manager secret has Secrets Manager pricing when deployed.
- No customer-managed KMS key cost is introduced.

Production-hardening posture:

- API and worker identities are separate now, before ECS task definitions exist.
- Execution and task responsibilities are separated now.
- ECR, logs, SQS, S3, and secret access are scoped to known resources and future resource contracts.
- Future ECS task definitions should consume these role outputs directly rather than creating new broad workload roles.

## Stage 4G Public Application Edge

Stage implemented:

- Stage 4G adds the deployment-ready public edge for the application.

Ownership/root:

- Certificate and DNS validation live in `modules/acm-dns`.
- ALB, target group, listeners, and ALB access-log bucket live in `modules/alb`.
- The development orchestration and Route 53 application alias live in `environments/development/edge.tf`.
- The development root owns edge state under `environments/development/terraform.tfstate`.
- Bootstrap, shared ECR, VPC, security groups, RDS, SQS, artifact S3, and workload IAM resources are unchanged.

Route 53 and domain contract:

- The domain `chisomeze.online` is owned outside Terraform through Namecheap.
- Terraform does not create the Route 53 hosted zone.
- The development root requires `application_domain_name`, for example `app.chisomeze.online`.
- The development root requires an explicit existing `route53_zone_id`.
- Before deployment, the Namecheap domain must delegate DNS to the Route 53 public hosted zone nameservers.

ACM/DNS validation model:

- ACM requests one public certificate for the exact application FQDN.
- DNS validation records are derived from ACM `domain_validation_options`.
- `aws_acm_certificate_validation` produces the certificate ARN consumed by the HTTPS listener.
- The certificate uses `create_before_destroy` for replacement safety.
- No customer-managed KMS key is used for ACM.

Public DNS flow:

```text
client
  -> Route 53 A alias for application_domain_name
  -> ALB DNS name / ALB hosted zone ID
  -> HTTPS listener
  -> API target group
```

ALB design:

- The ALB is internet-facing and spans both development public subnets.
- It uses only the existing ALB security group from the security-group module.
- Public edge ingress remains the existing TCP 80/443 contract.
- The ALB forwards only to the API target group on TCP 80.
- FastAPI TCP 8000, PostgreSQL TCP 5432, SSH, and worker traffic are not exposed by the ALB.

HTTP/HTTPS behavior:

- HTTP port 80 never forwards application traffic.
- HTTP redirects to HTTPS port 443 with HTTP 301 while preserving host, path, and query.
- HTTPS port 443 terminates TLS with the validated ACM certificate and forwards to the API target group.
- The TLS policy is `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09`, a current TLS 1.3/TLS 1.2 AWS policy that avoids legacy TLS 1.0/1.1.

Target group and health checks:

- Target type is `ip` for ECS/Fargate tasks using awsvpc networking.
- Target protocol is HTTP and target port is 80 for the future Nginx container.
- Health check path is `/health`.
- `/health` is used because the ALB should evaluate whether the task can answer traffic.
- `/ready` is not used because dependency failures such as a temporary PostgreSQL outage should not automatically mark every task unhealthy and trigger replacement churn.
- Health check matcher is `200-399`, with healthy threshold 2, unhealthy threshold 3, interval 30 seconds, and timeout 5 seconds.

Deregistration/draining:

- Target deregistration delay is 30 seconds.
- This gives in-flight requests time to drain during ECS deployments without relying on the slower 300-second default for small development rollouts.

ALB hardening:

- Invalid header dropping is enabled.
- HTTP/2 is enabled.
- Idle timeout is 60 seconds.
- Desync mitigation mode is `defensive`.
- Development sets ALB deletion protection to false for controlled teardown. Production should enable it through the same module input.

ALB access logging:

- Access logging is enabled now.
- Logs use a dedicated private S3 bucket owned by the ALB module.
- The application artifact bucket is not reused for ALB logs.
- Log prefix is `alb`; AWS writes beneath `alb/AWSLogs/<account-id>/`.
- Bucket policy grants `s3:PutObject` to the current ALB log-delivery service principal `logdelivery.elasticloadbalancing.amazonaws.com`.
- The PutObject resource is scoped to the intended account-specific log prefix.
- `aws:SourceArn` and `aws:SourceAccount` scope delivery to load balancers from the current account and region.

Log bucket security:

- Full S3 Public Access Block is enabled.
- Object ownership is `BucketOwnerEnforced`.
- SSE-S3 with `AES256` is enabled.
- No customer-managed KMS key or alias is created.
- Versioning is enabled.
- TLS-only bucket policy denies S3 actions when `aws:SecureTransport = false`.
- `force_destroy = false`.

Log retention/cost:

- Development access-log retention is 30 days.
- Noncurrent log versions also expire after 30 days.
- Incomplete multipart uploads abort after 7 days.
- ALB has hourly and LCU-related charges when deployed.
- Route 53 hosted zones and queries may incur charges depending on the DNS setup.
- S3 access-log storage and requests incur cost.
- Public ACM certificates for integrated AWS services do not require a project-created certificate key or customer-managed KMS architecture.
- No cloud runtime cost is incurred until the operator deploys the Terraform.

Connection logs:

- ALB access logging is mandatory and implemented in this stage.
- Separate ALB connection logs are not enabled here because the current requirement is request/access logging, and connection logs add another data source and storage cost that should be evaluated with observability requirements.

WAF ownership:

- WAF is intentionally implemented as a separate Stage 4H security-edge component.

X-Forwarded header contract:

- The ALB will provide forwarded request information such as `X-Forwarded-For` and `X-Forwarded-Proto`.
- Future Nginx/FastAPI configuration must trust and process proxy headers deliberately.

Production-hardening contract:

- HTTPS, HTTP-to-HTTPS redirect, modern TLS, access logging, invalid-header dropping, multi-AZ ALB placement, target type, and private target relationship are correct now.
- Production should mainly adjust policy values such as deletion protection, log retention, WAF posture, and DNS naming without rewriting the edge architecture.

## Stage 4H AWS WAF Application Protection

Stage implemented:

- Stage 4H adds AWS WAFv2 application-layer protection for the internet-facing ALB.

Ownership/root:

- The reusable implementation lives in `modules/waf`.
- The development deployment decision lives in `environments/development/waf.tf`.
- The development root owns WAF state under `environments/development/terraform.tfstate`.
- Bootstrap, shared ECR, VPC, security groups, RDS, SQS, artifact S3, workload IAM, ACM/DNS, and ALB resources are unchanged.

Association model:

- The Web ACL scope is `REGIONAL`.
- The Web ACL is associated only with the ALB ARN supplied by `module.alb.alb_arn`.
- The module does not create or own ALB resources.
- CloudFront scope is not used.

Default action:

- The Web ACL default action is `ALLOW`.
- Requests that do not match explicit protections continue to the ALB.
- Known malicious traffic is blocked through managed rule groups and the rate-limit rule.

AWS managed rule groups:

- `AWSManagedRulesCommonRuleSet`
- `AWSManagedRulesKnownBadInputsRuleSet`
- `AWSManagedRulesSQLiRuleSet`
- `AWSManagedRulesAmazonIpReputationList`

Managed-rule blocking behavior:

- Managed rule groups use `override_action = none`.
- The WAF does not place the entire baseline in Count mode.
- False positives should be handled later through specific sub-rule tuning, not by weakening the whole Web ACL.

Managed-rule versioning contract:

- The module accepts explicit version inputs for each managed rule group.
- Development exposes those versions as required variables.
- The operator must query AWS for currently supported versions before the authenticated deployment plan.
- The code does not invent AWS managed rule version strings.

Rule priority order:

- Priority 10: Common Rule Set.
- Priority 20: Known Bad Inputs.
- Priority 30: SQLi.
- Priority 40: Amazon IP Reputation.
- Priority 50: application IP rate limit.

Rate limiting:

- The development rate limit is 2000 requests per IP over 300 seconds.
- The rule aggregates by source IP and blocks matching traffic.
- This is an initial abuse and application-layer DDoS guardrail.
- Production thresholds must be tuned from legitimate traffic characteristics.
- The threshold must avoid becoming accidental denial-of-service for NAT, VPN, or shared corporate clients.

Telemetry:

- CloudWatch metrics and sampled requests are enabled for the Web ACL and every rule.
- Actual CloudWatch alarms and SNS routing remain in the later observability stage.

WAF logging:

- WAF logs are enabled.
- Logs go to a dedicated CloudWatch Logs log group.
- The log group name begins with `aws-waf-logs-`.
- Development log retention is 30 days.
- Logs are not written to ECS application log groups.
- No Firehose delivery path is created in this stage.

Log privacy:

- WAF logging redacts the `Authorization` and `Cookie` headers.
- URI and path are not redacted because they are operationally useful for security investigations.
- Applications must not put secrets in URL paths or query parameters.
- WAF logs can still contain sensitive request metadata, so log access must remain restricted.

Encryption decisions:

- CloudWatch Logs uses service-managed encryption at rest in this stage.
- No customer-managed KMS key or alias is created.
- No `kms_key_id` or `kms:Decrypt` permission is added.

WAF vs Shield:

- WAF rate limiting is application-layer request control.
- WAF is not a replacement for AWS Shield.
- Shield Standard is baseline AWS protection for supported resources.
- Shield Advanced is not implemented because it adds material cost and requires explicit business approval.

Explicitly omitted premium features:

- Bot Control is not enabled.
- Fraud Control is not enabled.
- Account Takeover Prevention is not enabled.
- CAPTCHA and Challenge actions are not enabled.
- Anonymous IP blocking is not enabled as a blanket rule because legitimate users can use VPN or proxy networks.

Cost decisions:

- AWS WAF charges for Web ACLs, rules or managed rule processing, requests processed, and logging destination/storage where applicable.
- The selected baseline avoids premium managed rule groups until justified.
- CloudWatch log retention is finite at 30 days for development.
- No WAF runtime cost exists until Terraform is deployed.

Production-hardening posture:

- REGIONAL ALB association, managed rule enforcement, rate limiting, metrics, sampled requests, logging, and privacy redaction are implemented now.
- Production should tune managed rule versions, rule exceptions, rate thresholds, and retention without replacing the module boundary.

## Stage 4I-A ECS Readiness Runtime Remediation

Stage implemented:

- Stage 4I-A prepares the application runtime contract required before ECS Terraform is created.
- No ECS cluster, ECS service, task definition, target group, listener rule, autoscaling, or deployment resource is implemented in this substage.

Ownership/root:

- Runtime remediation lives under the application and Docker runtime files.
- This document records the infrastructure-facing contract for the future ECS stage.
- Existing bootstrap, shared registry, VPC, security group, RDS, SQS, S3 artifact, workload IAM, ACM/DNS, ALB, and WAF Terraform modules remain unchanged.

Security decisions:

- Nginx remains the public task entrypoint and proxies to the API container.
- Local Docker Compose resolves the API upstream through the Compose service DNS name `api`.
- Future ECS awsvpc tasks must run Nginx and API in the same task so Nginx can proxy to loopback instead of depending on a Compose-only hostname.
- Cloud runtime configuration must use discrete database host, port, database name, username, and password values instead of a committed plaintext database URL.
- The API does not require static AWS credentials; AWS SDK calls must use the ECS task role credential provider.
- The worker performs SQS receive/delete and S3 artifact writes through its task role.

Cost decisions:

- No new AWS cost is introduced by this remediation because no infrastructure is created.
- The future ECS design can keep low-cost development capacity choices while preserving the production-grade trust boundaries already defined by the security groups.

Production-hardening decisions:

- Database connectivity is explicitly configurable for RDS and compatible with Secrets Manager-sourced credentials in the future ECS task definition.
- Job creation writes an outbox event in the same database transaction as the job record.
- The worker publishes pending outbox events to SQS and processes SQS messages idempotently.
- S3 artifact writes use the existing artifact bucket contract and do not require application-level ACLs or customer-managed KMS.
- Container shutdown handling remains signal-aware so ECS stop events can drain cleanly within the task stop timeout.

Intentional trade-offs:

- The API creates database-backed outbox events instead of directly depending on SQS for request success.
- The worker owns outbox dispatch and queue consumption, which reduces API blast radius and requires the worker IAM role to include SQS send permissions.
- Local runtime behavior remains Docker Compose-compatible while cloud runtime values are supplied by environment variables and task role credentials.

Deferred components and why:

- ECS Terraform is deferred until the runtime contract is ready and reviewable.
- Secrets Manager wiring is deferred to the ECS task definition stage because no task definition exists yet.
- ALB target group and listener wiring remain deferred to the ECS service stage.
- CloudWatch ECS alarms and dashboards remain deferred to the observability stage.

## Stage 4I-A.1 Worker Lease, Crash Recovery, and Fencing

Stage implemented:

- Stage 4I-A.1 hardens runtime concurrency before IAM and ECS Terraform are written.
- No Terraform module, workload IAM policy, ECS resource, deployment, or AWS state is changed in this substage.

Atomic job claim:

- Workers still acquire jobs through a single database update guarded by job status.
- Pending and failed jobs are claimable.
- Processing jobs are claimable only when their processing lease is stale.
- Fresh processing jobs owned by another worker are not claimable.

Job processing fencing token:

- Each successful job claim stores a Python-generated `processing_token`.
- Job completion, job failure, and lease renewal require the matching token.
- A stale worker cannot complete, fail, or renew a job after another worker has reclaimed it.

Job processing lease and crash recovery:

- Job claims store `processing_started_at`.
- If a worker crashes while a job is `processing`, another worker can reclaim it after `JOB_PROCESSING_LEASE_SECONDS`.
- The default processing lease is 120 seconds, which is deliberately longer than the 60-second SQS visibility timeout.

SQS visibility heartbeat contract:

- The worker starts a heartbeat only after it has acquired the database job claim.
- The heartbeat renews the database processing lease with the active processing token.
- The heartbeat also calls SQS `ChangeMessageVisibility` before the current visibility timeout expires.
- The default heartbeat interval is 30 seconds and must remain less than `SQS_VISIBILITY_TIMEOUT_SECONDS`.
- Heartbeat failures are logged without exposing credentials or secrets.

Atomic outbox claim:

- Outbox rows are still claimed with `FOR UPDATE SKIP LOCKED`.
- Pending and failed outbox rows are claimable.
- Publishing rows are claimable only after `OUTBOX_CLAIM_LEASE_SECONDS` makes them stale.

Outbox claim fencing token:

- Each outbox claim batch receives a Python-generated `claim_token`.
- Marking an outbox event published or failed requires both event id and matching claim token.
- A stale dispatcher cannot overwrite the state written by a newer claimant.

Stale publishing recovery:

- If a worker crashes after setting an outbox event to `publishing`, the row can be reclaimed after the outbox lease expires.
- Published rows clear claim and lock fields.
- Failed rows clear claim and lock fields while preserving a safe error value.

Delivery guarantee:

- The transactional outbox provides durable eventual dispatch.
- Exactly-once delivery is not claimed.
- If SQS `SendMessage` succeeds and the worker crashes before marking the outbox row `published`, the event can later be redispatched.
- Duplicate SQS messages are acceptable because SQS Standard is at-least-once and job processing is durably idempotent behind fenced ownership.

Durable idempotency requirement:

- Completed duplicate jobs do not regenerate artifacts.
- Duplicate messages for jobs currently processing under a fresh lease do not mark the job failed and do not corrupt another worker's claim.
- SQS messages are deleted only after durable completion or when the durable job is already completed.

Blocked follow-on stages:

- Stage 4I-B workload IAM remains blocked until the runtime tests pass.
- Stage 4I-C ECS remains blocked until the runtime tests pass and the IAM delta is applied.

## Stage 4I-B/C Workload IAM Alignment and ECS Runtime

Stage implemented:

- Stage 4I-B/C aligns workload IAM with the validated transactional outbox runtime and adds the hardened ECS/Fargate runtime.
- Development state ownership remains in `environments/development/terraform.tfstate`.

IAM correction:

- The API task role no longer owns `sqs:SendMessage`.
- The API task role intentionally has no SQS, S3, RDS, KMS, or Secrets Manager application permissions in the current runtime.
- The worker task role owns `sqs:SendMessage` because the worker dispatches transactional outbox rows to SQS.
- The worker task role remains the SQS consumer with `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:ChangeMessageVisibility`, and `sqs:GetQueueAttributes`.
- Worker SQS permissions remain scoped only to the main queue ARN.
- Worker S3 permissions remain scoped only to `${artifact_bucket_arn}/reports/*` for `s3:PutObject` and `s3:GetObject`.
- Execution role responsibilities are unchanged: image pulls, CloudWatch log writes, and RDS-managed secret retrieval for ECS injection.
- Application task roles do not receive Secrets Manager permissions.
- No broad SQS, S3, RDS, KMS, or wildcard action permissions are introduced.

ECS design:

- The reusable implementation lives in `modules/ecs`.
- Development wiring lives in `environments/development/compute.tf`.
- The cluster is Fargate-only; no ECS EC2 capacity, launch templates, Auto Scaling Groups, or EC2 instances are created.
- Enhanced Container Insights is enabled for the cluster. This emits additional CloudWatch telemetry and increases monitoring cost.
- All task definitions use `FARGATE`, `awsvpc`, Linux, and `X86_64`.
- Image inputs are required immutable digest references in `<repository-uri>@sha256:<64-hex-digest>` form and reject `:latest`.

API task:

- The API task definition contains two essential containers: FastAPI and Nginx.
- FastAPI listens on port 8000 inside the task and is not directly attached to the ALB.
- Nginx listens on port 80 and is the only ALB target container.
- Nginx uses `NGINX_UPSTREAM_HOST=127.0.0.1` and `NGINX_UPSTREAM_PORT=8000` because colocated containers share the task network namespace.
- The FastAPI container has an ECS health check using the existing Python standard library probe against `http://127.0.0.1:8000/health`.
- Nginx depends on FastAPI with `condition = HEALTHY`.
- `/ready` is not used for container liveness to avoid database dependency churn.
- `readonlyRootFilesystem` is not enabled in this stage. Nginx performs runtime template rendering and uses standard PID/cache/temp paths, and the Python images have not yet been validated with explicit writable mount points for every runtime temp path.

Worker task:

- The worker task definition contains one essential worker container.
- It has no inbound ports and no ALB integration.
- It receives `SQS_QUEUE_URL`, `ARTIFACT_BACKEND=s3`, `ARTIFACT_BUCKET_NAME`, `AWS_REGION`, and the validated lease and heartbeat settings.
- It owns outbox dispatch, SQS receive/delete/change-visibility behavior, S3 artifact writes, and durable database completion.

Migration task:

- The migration task definition uses the API image with `python -m application.migrations`.
- It is a one-off task definition, not a continuously running service.
- It does not include Nginx.
- It logs to the API log group with a distinct `migration` stream prefix.
- The future run-task network contract is application-private subnets, no public IP, and the existing worker security group because that policy has no inbound access, HTTPS egress, and PostgreSQL egress to RDS.

Database and secrets:

- API, worker, and migration containers use discrete `DB_HOST`, `DB_PORT`, and `DB_NAME` values.
- `DB_USERNAME` and `DB_PASSWORD` are injected from the RDS-managed Secrets Manager secret JSON keys `username` and `password`.
- Terraform does not place plaintext database credentials in source, variables, outputs, or container environment JSON.
- Linux Fargate platform version 1.4.0 or later is required for Secrets Manager JSON-key injection. Development uses `LATEST`, which must resolve to a compatible platform at deployment time.

Network and load balancing:

- API and worker services run only in application-private subnets.
- `assign_public_ip = false` for both services.
- API service uses only the existing API security group.
- Worker service uses only the existing worker security group.
- No new security groups are created.
- The ALB attaches only to the Nginx container on port 80 through the existing target group.
- Worker has no load balancer block.

Logging:

- Terraform creates log groups for API, Nginx, and worker using the exact names assumed by workload IAM:
  - `/ecs/production-cloud-reliability/development/api`
  - `/ecs/production-cloud-reliability/development/nginx`
  - `/ecs/production-cloud-reliability/development/worker`
- Log retention is 7 days in development.
- CloudWatch Logs uses service-managed encryption.
- ECS does not auto-create log groups, and execution roles do not need `logs:CreateLogGroup`.
- FireLens and OpenTelemetry are deferred.

Deployment controls:

- API and worker services use ECS rolling deployments.
- Deployment circuit breaker rollback is enabled for both services.
- `deployment_minimum_healthy_percent = 100` and `deployment_maximum_percent = 200`.
- API service uses a 60-second health check grace period.
- ECS Exec is disabled and no SSM permissions are added.
- Application Auto Scaling is deferred to Stage 4J.

Migration release order:

- Register new task definitions.
- Run the one-off migration task.
- Wait for the migration task to exit successfully.
- Deploy or update API and worker services only after migration success.
- If migration fails, stop the release and do not roll services automatically.

Cost decisions:

- Fargate task runtime charges apply when deployed.
- API and worker desired count `1` is a development cost decision.
- Rolling deployments can temporarily double running tasks.
- CloudWatch log ingestion and storage costs apply.
- Enhanced Container Insights adds CloudWatch telemetry cost.
- ALB, WAF, RDS, SQS, and S3 costs belong to earlier stages.
- No Fargate Spot, ECS EC2 fleet, customer-managed KMS, dashboards, or alarms are created in this stage.

Production-hardening posture:

- Security boundaries are deployment-ready even though development capacity is intentionally small.
- Image mutability is rejected at Terraform variable validation.
- Secrets are injected by ECS through execution roles, not exposed to application task roles.
- Autoscaling, observability alarms, deployment workflows, staging, and production remain deferred follow-on stages.

## Stage 4J ECS Service Auto Scaling and Deployment Resilience

Stage implemented:

- Stage 4J adds AWS Application Auto Scaling for existing ECS/Fargate API and worker services.
- The reusable implementation lives in `modules/ecs-autoscaling`.
- Development wiring lives in `environments/development/autoscaling.tf`.
- No IAM, network, KMS, application runtime, Prometheus, Grafana, OpenTelemetry, dashboards, or general operational alarms are added.

Autoscaling ownership:

- Terraform creates and configures ECS services, sets initial desired count, and defines scalable min/max capacity.
- Application Auto Scaling owns runtime ECS service `DesiredCount`.
- ECS service resources ignore only `desired_count` drift so Terraform does not fight scaling decisions.

API scaling:

- API scalable target uses `service/<cluster-name>/<api-service-name>`.
- Development API min capacity is `1`.
- Development API max capacity is `4`.
- API target tracking uses `ECSServiceAverageCPUUtilization` with a 60 percent target.
- API target tracking uses `ECSServiceAverageMemoryUtilization` with a 70 percent target.
- Scale-out cooldown is 60 seconds.
- Scale-in cooldown is 300 seconds.
- Multiple target-tracking policies scale out if any policy requires scale out; scale in occurs only when all scale-in-enabled policies agree.
- ALB request-count-per-target scaling is deferred until load testing establishes a defensible request-per-task target.

Worker scaling:

- Worker scalable target uses `service/<cluster-name>/<worker-service-name>`.
- Development worker min capacity is `1`.
- Development worker max capacity is `4`.
- Worker scale-to-zero is prohibited while the worker owns transactional-outbox dispatch.
- If worker desired count were zero, the API could continue committing durable outbox rows but no process would dispatch them to SQS.
- Worker scaling uses target tracking with CloudWatch metric math for backlog per running worker task.
- The expression is `ApproximateNumberOfMessagesVisible / RunningTaskCount`.
- `ApproximateNumberOfMessagesVisible` comes from `AWS/SQS` using the real queue name.
- `RunningTaskCount` comes from `ECS/ContainerInsights` using the real ECS cluster and worker service names.
- The worker backlog-per-task target is a required environment input with no default.
- Select the backlog target from acceptable queue wait time divided by average processing time, or equivalent measured workload-capacity reasoning.
- Worker CPU scaling is intentionally not configured because queue consumers can be network, database, or S3 bound while CPU remains low.

Worker graceful scale-in:

- Worker container `stopTimeout` is 120 seconds, the maximum supported Fargate stop timeout.
- This aligns with the 120-second job-processing lease.
- `stopTimeout` does not guarantee job completion.
- If a worker is terminated during processing, SQS redelivery, stale database lease reclaim, fencing tokens, and idempotent retry preserve correctness.
- ECS task scale-in protection is deferred because current jobs are lightweight and already protected by the durable retry model. It can be reconsidered if jobs become long-running or expensive to restart.

Deployment resilience:

- Existing ECS deployment circuit breakers remain enabled with rollback.
- Rolling deployments keep minimum healthy percent `100` and maximum percent `200`.
- API health check grace period remains 60 seconds.
- Stage 4J does not switch to blue/green, canary, or linear deployment.
- Application Auto Scaling suspends dynamic scale-in during ECS deployments while scale-out can continue.
- The circuit breaker protects task-start and steady-state deployment failures.
- Future CloudWatch deployment alarms should protect application/SLO regressions after Stage 4L creates evidence-based alarms.

CloudWatch ownership:

- Application Auto Scaling automatically manages the CloudWatch alarms required by target-tracking policies.
- Stage 4J does not manually duplicate or edit autoscaling-managed alarms.
- General operational dashboards and alarms remain Stage 4L.

Observability relationship:

- Stage 4J uses CloudWatch/AWS-native metrics for autoscaling because Application Auto Scaling integrates natively with those signals.
- Prometheus remains future application/platform metrics and SLI/SLO tooling.
- Grafana remains future visualization and correlation tooling.
- OpenTelemetry remains future telemetry instrumentation, collection, and export for traces, metrics, and logs.
- OpenTelemetry is not a log storage backend.
- Autoscaling must keep functioning if future Prometheus, Grafana, or OpenTelemetry components are unavailable.

Cost decisions:

- Application Auto Scaling itself is not the primary cost driver.
- Cost impact comes from additional Fargate tasks created during load, CloudWatch metrics and telemetry, enhanced Container Insights, and log ingestion/storage.
- Development max capacity of `4` limits cost exposure for each service.
- Worker min capacity of `1` accepts baseline Fargate cost so outbox dispatch remains continuously available.
- No Fargate Spot, customer-managed KMS, ECS EC2 fleet, Prometheus, Grafana, OpenTelemetry collector, dashboards, or general alarms are created in this stage.

Production-hardening posture:

- Runtime scaling depends on AWS-native metrics, not the future higher-level observability stack.
- The worker remains always available for durable outbox dispatch.
- Desired count ownership is explicit and does not mask unrelated ECS service drift.
- Stage 4K remains the next network/private-service routing stage.

## Stage J-A Production Observability Foundation

Stage implemented:

- Stage J-A establishes the managed observability foundation for the ECS/Fargate runtime.
- The reusable infrastructure implementation lives in `modules/observability`.
- Development wiring lives in `environments/development/observability.tf`.
- Application changes are limited to metrics, tracing setup, worker loopback metrics, and trace/log correlation.

Telemetry architecture:

- CloudWatch is the AWS-native operational plane for infrastructure metrics, ECS enhanced Container Insights, ALB/RDS/SQS metrics, CloudWatch Logs, alarms, dashboards, and control-plane signals.
- Amazon Managed Service for Prometheus is the managed Prometheus-compatible backend for application/SRE metrics.
- Amazon Managed Grafana is the visualization and query plane for CloudWatch, AMP, and X-Ray.
- ADOT collects and exports telemetry.
- AWS X-Ray stores and queries distributed traces.
- OpenTelemetry is not a log storage backend.

Log pipeline:

- Structured stdout/stderr logs continue to flow through ECS `awslogs` to CloudWatch Logs.
- Stage J-A does not duplicate the same application logs through OTLP.
- Logs include `request_id`, `correlation_id`, and, when available, OpenTelemetry `trace_id` and `span_id`.

Metrics and cardinality:

- API `/metrics` remains available for local collector scraping.
- API request metrics preserve existing metric names and move labels to bounded method, route template, and status class dimensions.
- Worker metrics are served only on loopback for same-task ADOT scraping.
- Worker metrics cover outbox dispatch, job processing results, processing duration, duplicate handling, job claims, outbox reclaim events, and heartbeat failures.
- Prometheus labels must not contain UUIDs, customer IDs, job IDs, request IDs, correlation IDs, raw URLs, S3 keys, or exception messages.
- Cardinality is an explicit cost and reliability concern because AMP ingestion cost grows with sample volume and time-series count.

Tracing and sampling:

- OpenTelemetry instruments FastAPI inbound requests, psycopg database operations, and botocore/boto3 AWS SDK calls where supported.
- Worker business spans include `outbox.dispatch`, `sqs.consume`, `job.process`, and `artifact.write`.
- Service names are stable: `production-cloud-reliability-api` and `production-cloud-reliability-worker`.
- Sampling is parent-based trace ID ratio sampling and is configurable.
- Development defaults to a 0.1 sample ratio; production must tune sampling from cost and diagnostic needs.

ADOT ECS task design:

- API and worker tasks each include a non-essential ADOT sidecar.
- Migration tasks do not include ADOT by default.
- The collector image must be an immutable digest reference.
- OTLP endpoints listen only on same-task localhost.
- API collector scrapes `127.0.0.1:8000/metrics`.
- Worker collector scrapes `127.0.0.1:9464`.
- Collectors export metrics to AMP with Prometheus remote write and SigV4 authentication.
- Collectors export traces to X-Ray.
- Collector logs use existing API/worker CloudWatch log groups with stream prefix `otel`.

IAM and trust boundary:

- ECS task roles are task-level identities shared by all containers in a task.
- API and worker task roles therefore receive telemetry export permissions used by the ADOT sidecar.
- AMP permission is scoped to the AMP workspace through `aps:RemoteWrite`.
- X-Ray trace-write actions are limited to `xray:PutTraceSegments` and `xray:PutTelemetryRecords`; these require wildcard resource scope.
- Grafana uses a customer-managed read-only role trusted only by `grafana.amazonaws.com`.
- Grafana can query CloudWatch, AMP, and X-Ray but receives no write access to ECS, RDS, SQS, S3, or IAM.

CloudWatch alarms:

- Alarm notifications go to an SNS topic with no subscription endpoint configured.
- Deterministic critical alarms cover DLQ visible messages and ALB unhealthy targets.
- SLO-dependent thresholds for API 5XX rate, API p95 latency, queue age, RDS CPU, and RDS free storage are explicit inputs with no fake defaults.
- No alarm is created solely because there is no traffic.

Dashboard and Logs Insights:

- The development CloudWatch dashboard covers edge, ECS, queue, database, and autoscaling context.
- Query definitions cover API errors, worker failures, request/correlation lookup, and trace ID lookup.

SLI/SLO model:

- Measurable SLIs include API availability, API error rate, API latency, job processing success, job processing latency, queue wait/age, and DLQ occurrence.
- Stage J-A does not invent final SLO targets such as 99.9 percent or 99.99 percent.

Failure isolation:

- API request processing, job creation, outbox dispatch, SQS consumption, database writes, and S3 artifact generation do not depend on Grafana, AMP, X-Ray, or ADOT being healthy.
- Telemetry failure degrades observability, not business processing.
- Autoscaling remains AWS-native and independent of Prometheus, Grafana, and OpenTelemetry availability.

FinOps:

- AMP ingestion/query cost depends on scrape volume and cardinality.
- AMG cost depends on workspace and active users.
- X-Ray cost depends on trace volume.
- CloudWatch metrics, alarms, dashboards, Logs Insights, and logs create operational cost.
- Enhanced Container Insights remains enabled.
- ADOT sidecars consume Fargate CPU/memory resources.
- No customer-managed KMS or VPC endpoints are introduced in this stage.

## Stage J-B Observability Hardening And Incident Readiness

Stage implemented:

- Stage J-B adds the operating model for the Stage J-A observability foundation.
- The stage is documentation-only and creates no AWS resources.

Ownership/root:

- Runtime observability resources remain owned by `environments/development` through `modules/observability`.
- Operational contracts live under `docs/operations/observability`.
- Incident runbooks live under `docs/operations/runbooks`.

Security decisions:

- Telemetry correlation uses `request_id`, `correlation_id`, `trace_id`, and `span_id` in logs and traces.
- High-cardinality identifiers remain forbidden as metric labels.
- No new IAM permissions, telemetry backends, collectors, VPC endpoints, or KMS resources are introduced.

Cost decisions:

- Stage J-B reinforces existing cost controls around bounded Prometheus labels, configurable trace sampling, finite development log retention, and no invented dashboards or alarms.
- It does not add cost estimates without deployment and traffic assumptions.

Production-hardening decisions:

- The SLI/SLO contract separates direct SLIs from operational proxies and supporting diagnostics.
- Final SLO values, burn-rate alarms, and paging policy remain deferred until business targets and measurement windows are agreed.
- Runbooks define metric-to-log-to-trace triage paths and recovery criteria before live incident drills.

Intentional trade-offs:

- CloudWatch alarm thresholds that depend on business tolerance remain Terraform inputs rather than fake defaults.
- Notification delivery is not claimed tested because the SNS topic has no configured subscriber.
- Runtime behavior in AWS is not claimed until the first deployment proves telemetry export, dashboards, alarms, traces, and rollback evidence.

Deferred components:

- VPC endpoints, KMS, additional observability backends, burn-rate alarms, incident-management integrations, production dashboards, and live failure drills remain deferred.

## Stage K Selective Private AWS-Service Routing

Stage implemented:

- Stage K adds one regional Amazon S3 Gateway VPC Endpoint.
- The reusable implementation lives in `modules/vpc-endpoints`.
- Development wiring lives in `environments/development/endpoints.tf`.

Ownership/root:

- The development root owns the endpoint in `environments/development/terraform.tfstate`.
- The existing VPC module continues to own VPCs, subnets, route tables, NAT gateways, Internet gateways, route-table associations, and default routes.
- The existing S3 artifact module continues to own the artifact bucket and its bucket policy.

Security decisions:

- The endpoint is associated only with application-private route tables.
- Public and database-private route tables are not associated.
- S3 Gateway Endpoints do not use endpoint ENIs, subnet IDs, private DNS settings, or endpoint security groups.
- No application security-group, workload IAM, artifact bucket policy, source VPC endpoint condition, KMS, or network ACL change is introduced.
- The endpoint policy allows `s3:GetObject` and `s3:PutObject` only on the artifact bucket `reports/*` path and `s3:GetObject` on `arn:aws:s3:::prod-${region}-starport-layer-bucket/*` for ECR layer downloads.
- The endpoint policy does not allow `s3:DeleteObject`, `s3:*`, or bucket listing.

Routing decisions:

- Existing application-private `0.0.0.0/0` routes to the NAT Gateway remain unchanged.
- AWS installs the S3 managed prefix-list route through the gateway endpoint association.
- The S3 prefix-list route is more specific than `0.0.0.0/0`, so same-Region S3 traffic uses the endpoint while other HTTPS egress continues through NAT.

Cost decisions:

- S3 Gateway Endpoint has no additional endpoint hourly charge and no gateway-endpoint data-processing charge.
- NAT hourly and data-processing costs remain for non-S3 traffic.
- Interface endpoints are deferred because they add fixed endpoint-hour and data-processing cost and require measured traffic, security, or availability justification.

Production-hardening decisions:

- The endpoint policy is deliberately not artifact-only because ECR image-layer downloads require access to the regional ECR starport S3 bucket.
- Stage K does not claim fully private ECR routing. ECR API and ECR DKR remain NAT-routed until their interface endpoints are deliberately implemented.
- External API access remains available from private application subnets through NAT without assigning public IPs to Fargate tasks.

Intentional trade-offs:

- NAT remains a cost and availability dependency in development.
- SQS, ECR API, ECR DKR, Secrets Manager, CloudWatch Logs, AMP, and X-Ray remain NAT-routed.
- `aws:sourceVpce` enforcement on the artifact bucket is deferred so CI/CD, administrative, troubleshooting, and future approved access paths are not accidentally blocked.

Deferred components:

- SQS, ECR API, ECR DKR, Secrets Manager, CloudWatch Logs, AMP, and X-Ray interface endpoints remain deferred.
- NAT replacement, NAT removal, NAT per-AZ changes, private-only egress, KMS, and source-VPCE bucket enforcement remain future decisions.

Production review triggers:

- NAT processed-byte cost rises materially.
- Compliance requires private AWS API paths.
- Production removes general Internet access.
- NAT availability becomes unacceptable.
- CloudWatch or telemetry volume justifies endpoint economics.
- Security model requires `aws:sourceVpce` bucket enforcement.

## Stage L Security Audit Plane

Stage implemented:

- Stage L adds the account/control-plane audit baseline.
- The reusable implementation lives in `modules/security-audit`.
- The shared composition root lives in `shared/security-audit`.

Ownership/root:

- CloudTrail is account governance, not development runtime infrastructure.
- The account audit plane has one Terraform owner: `shared/security-audit`.
- Development, staging, and production roots must not each create competing account-level trails.

Security decisions:

- One account-level multi-Region CloudTrail trail records read and write management events.
- Global service events are included.
- Log file validation is enabled.
- A dedicated audit bucket stores delivered logs.
- The audit bucket is separate from application artifacts, ALB logs, and Terraform state.
- Targeted EventBridge rules detect root activity, CloudTrail tampering, IAM privilege changes, network perimeter changes, S3 security posture changes, and successful console login without MFA.
- Security events target a dedicated security SNS topic.
- No application task role, ECS execution role, Grafana role, or ADOT collector receives audit bucket access.

Cost decisions:

- The first copy of ongoing CloudTrail management events delivered to S3 has no additional CloudTrail management-event delivery charge.
- S3 audit-log storage, S3 requests, EventBridge, and SNS usage can still create cost.
- Data events, network activity events, CloudTrail Insights, CloudTrail Lake, and full CloudTrail delivery to CloudWatch Logs are deferred cost items.

Production-hardening decisions:

- The trail is multi-Region even though the workload currently runs in `us-east-1`, so regional control-plane activity elsewhere is not silently missed.
- The audit bucket uses Public Access Block, `BucketOwnerEnforced`, versioning, SSE-S3 with `AES256`, `force_destroy = false`, and TLS-only bucket policy.
- The CloudTrail bucket policy scopes delivery to the exact trail ARN and `AWSLogs/<account-id>/*` path and requires CloudTrail's documented `bucket-owner-full-control` delivery ACL condition.
- No customer-managed KMS key, Object Lock, MFA Delete, CloudTrail Lake, CloudTrail Insights, broad data events, GuardDuty, Security Hub, AWS Config, or automated remediation is introduced.

Intentional trade-offs:

- Audit logs are durable and log-file validation is enabled, but the bucket is not immutable.
- Security SNS has no subscription until a real email, chat, incident-management, SIEM, or SOC endpoint is supplied.
- EventBridge rules are targeted security visibility, not complete threat detection.
- CloudTrail records activity; investigation establishes intent and authorization.

Deferred components:

- Organization trail, centralized security account, Object Lock, SCP protections, CMK encryption, CloudTrail Lake, CloudTrail Insights, broad data-event logging, CloudTrail to CloudWatch Logs streaming, SIEM integration, and automated remediation remain future governance decisions.

Review triggers:

- AWS Organizations or multi-account adoption.
- compliance retention or immutability requirement.
- object-access auditing requirement.
- SIEM or SOC integration.
- SQL-style audit investigations.
- security team requires immutable retention.
- CloudTrail Insights or data-event requirements emerge.
