# Development Environment

This Terraform root owns development runtime infrastructure. Stage 4A created the development network foundation by instantiating the reusable VPC module. Stage 4B adds the development security-group trust graph. Stage 4C adds the private PostgreSQL RDS foundation. Stage 4D adds the asynchronous SQS job queue and DLQ. Stage 4E adds private S3 artifact storage. Stage 4F adds ECS workload IAM roles. Stage 4G adds the public ALB/ACM/Route 53 edge. Stage 4H adds AWS WAF application-layer protection. Stage 4I-B/C aligns workload IAM to the validated runtime and adds the Fargate ECS runtime.

State key:

```text
environments/development/terraform.tfstate
```

## Network

Development uses `10.10.0.0/16` across two Availability Zones:

| Tier | us-east-1a | us-east-1b |
| --- | --- | --- |
| Public | `10.10.0.0/24` | `10.10.1.0/24` |
| Application private | `10.10.10.0/24` | `10.10.11.0/24` |
| Database private | `10.10.20.0/24` | `10.10.21.0/24` |

Public subnets are for future ALB placement. Application-private subnets are for future ECS/Fargate API and worker tasks. Database-private subnets are for RDS placement.

Application and database subnets do not assign public IPv4 addresses on launch.

## Routing

Public subnets route `0.0.0.0/0` to the Internet Gateway.

Application-private subnets route `0.0.0.0/0` through one NAT Gateway for initial development egress.

Database-private subnets do not route to the Internet Gateway or NAT Gateway. They remain isolated for RDS.

## NAT Cost And Availability Trade-Off

Development uses `nat_gateway_strategy = "single"` to reduce lab cost. Both application-private subnets route through one NAT Gateway in the first configured AZ.

This is an intentional temporary availability trade-off. If the NAT AZ has an outage, private application egress from both AZs may be affected. Staging and production should later use `nat_gateway_strategy = "per_az"` where the availability and fault-isolation requirements justify the cost.

Later stages may evaluate VPC endpoints for ECR API, ECR DKR, S3, CloudWatch Logs, and Secrets Manager based on traffic volume, NAT processing cost, endpoint hourly cost, reliability, and operational complexity.

## Security Boundary

Stage 4B creates four deployment-ready security groups for the future ALB, future API ECS task, future worker ECS task, and PostgreSQL RDS database.

The initial trust graph is:

```text
Internet
  -> ALB TCP 80
  -> ALB TCP 443
  -> API ECS TCP 80

API ECS
  -> RDS TCP 5432
  -> HTTPS TCP 443 through NAT

Worker ECS
  -> RDS TCP 5432
  -> HTTPS TCP 443 through NAT
```

TCP 80 remains open on the ALB because the Stage 4G ALB listener redirects HTTP to HTTPS. TCP 443 is open for TLS termination at the ALB.

The API security group is not public. It accepts TCP 80 only from the ALB security group. The future FastAPI container port is not exposed directly to the ALB.

The worker security group has no inbound application rule because the worker is not behind the ALB and does not serve public or internal HTTP traffic.

The RDS security group trusts the API and worker security groups on TCP 5432. It does not trust `0.0.0.0/0`, the VPC CIDR, or subnet CIDR blocks.

API and worker egress is limited to TCP 443 to IPv4 destinations for HTTPS-based AWS APIs and permitted external dependencies through NAT, plus explicit TCP 5432 to the RDS security group.

No all-port, all-protocol workload egress is permitted. DNS rules are not added because the current VPC design is IPv4-only and Amazon VPC DNS behavior does not require broad workload egress rules in this security-group layer.

## Database

Stage 4C creates a private PostgreSQL RDS instance through the reusable `modules/rds` module.

Development configuration:

- PostgreSQL engine version `16.15`
- `db.t4g.micro` instance class for low-cost lab usage
- `gp3` encrypted storage with 20 GiB initial allocation and 100 GiB autoscaling ceiling
- service-managed storage encryption, with no customer-managed KMS key in this stage
- RDS-managed master user password, with no plaintext password in Terraform variables, tfvars, or outputs
- database-private subnets only
- RDS security group from Stage 4B
- `publicly_accessible = false`
- automated backups retained for 7 days
- explicit UTC backup and maintenance windows
- `copy_tags_to_snapshot = true`
- Single-AZ deployment for development cost control
- deletion protection disabled for development, but final snapshots are not skipped
- PostgreSQL and upgrade logs exported to CloudWatch Logs with 7-day retention
- standard RDS CloudWatch metrics through the managed RDS service integration
- Enhanced Monitoring enabled at 60-second intervals
- Performance Insights exposed by the module but disabled in development until the target instance class, retention, and cost policy are confirmed for deployment

The database subnet tier has no Internet Gateway or NAT Gateway default route. API and worker access is granted only through security-group references on TCP 5432.

## Production Database Contract

Staging and production should reuse the same RDS module with stricter root-level inputs:

- `multi_az = true` where the availability target requires standby failover
- `deletion_protection = true`
- `skip_final_snapshot = false`
- longer backup and log retention
- an instance class sized from load testing
- explicit Performance Insights or Database Insights posture once the final class and provider support are confirmed
- application secret access wired through IAM rather than plaintext configuration

RDS Proxy is intentionally not created in this stage. It can be added later if connection pooling, failover behavior, or Lambda-style burst protection becomes a demonstrated need.

## Asynchronous Job Queue

Stage 4D creates the regional SQS job queue used by the future API and worker architecture.

Development configuration:

- Standard SQS queue named `ProductionCloudReliabilityPlatform-development-jobs`
- dedicated DLQ named `ProductionCloudReliabilityPlatform-development-jobs-dlq`
- 60-second visibility timeout
- max receive count `3`
- 4-day main queue retention
- 14-day DLQ retention
- 20-second long polling
- zero delivery delay
- SQS-managed server-side encryption
- TLS-only deny resource policies on both queues
- DLQ redrive allow policy restricted to the main queue ARN

SQS is a regional AWS service and does not live inside the VPC. The queue root does not depend on VPC resources. Future private access can be evaluated through an SQS interface VPC endpoint when the endpoint, NAT, cost, and reliability model is defined.

SQS Standard provides at-least-once delivery. Messages can be duplicated or delivered out of order, so worker processing must be idempotent and anchored in durable PostgreSQL job state.

The worker deletes a message only after durable job completion. Failed processing leaves the message undeleted, visibility expires, and SQS retries delivery. After three failed receives, SQS moves the message to the DLQ for investigation or replay.

Long-running jobs must complete within 60 seconds or call `ChangeMessageVisibility` before the timeout.

## Queue Reliability Contract

The API role does not receive SQS permissions. The API creates jobs and outbox events in PostgreSQL transactionally.

The worker role owns both outbox dispatch and queue consumption. It receives `sqs:SendMessage`, `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:ChangeMessageVisibility`, and `sqs:GetQueueAttributes`, scoped only to the main queue ARN.

Neither role should receive SQS administrative permissions.

The transactional outbox removes the API-side dual-write to SQS. The worker dispatches outbox rows to SQS and processes messages with fenced, idempotent job ownership.

Queue observability will be wired in a later observability stage. Important metrics include visible messages, in-flight messages, oldest message age, sent/received counts, and DLQ message count.

## Artifact Storage

Stage 4E creates the private S3 bucket used for durable application-generated artifacts.

Initial artifact contract:

```text
reports/{job_id}/{report_id}.csv
```

Development configuration:

- bucket prefix `prod-cloud-reliability-dev-artifacts-`
- final globally unique bucket name exported from Terraform outputs
- full S3 Public Access Block enabled
- `BucketOwnerEnforced` object ownership
- ACLs disabled
- SSE-S3 encryption with `AES256`
- no customer-managed KMS key
- versioning enabled
- TLS-only deny bucket policy
- incomplete multipart uploads aborted after 7 days
- noncurrent object versions expired after 30 days
- `force_destroy = false`
- no current-object expiration rule
- no CORS
- no static website hosting
- no CloudFront

S3 is regional and does not live inside the VPC. Initial private application subnet access can use the existing NAT path. A future S3 Gateway VPC Endpoint should be evaluated in the network endpoint stage because it has no hourly charge, can remove S3 traffic from NAT, and improves private-service routing.

Future worker IAM should allow only required object actions for `reports/*`, such as `s3:PutObject` and `s3:GetObject`. `s3:DeleteObject` should be added only if a real artifact-delete workflow exists.

Future API IAM may need `s3:GetObject` for `reports/*` if the API serves reports directly or issues presigned URLs. Public bucket access is not required for downloads.

S3 data-plane auditing is not configured in this stage. CloudTrail S3 data events, central log archive integration, access requirements, and data-event cost should be handled by the centralized observability/security stage.

## Workload IAM

Stage 4F creates four ECS IAM roles through the reusable `modules/workload-iam` module:

- API execution role
- API task role
- worker execution role
- worker task role

All four roles trust only `ecs-tasks.amazonaws.com`.

Execution roles are for the ECS/Fargate platform. They pull container images, write container logs, and retrieve the RDS-managed Secrets Manager secret for ECS secret injection.

Task roles are exposed to application code. The API task role intentionally has no application AWS permissions in the current runtime. The worker task role can send to and consume from the main SQS job queue and put/get known report objects under `reports/*`.

The application task roles do not receive `secretsmanager:GetSecretValue`. Database credentials are intended to be injected by ECS at task start from the RDS-managed secret ARN. If that secret rotates, already-running containers do not receive the new environment value automatically; a new ECS deployment or task restart is required.

The development root constructs ECR repository ARNs from the current AWS account, `us-east-1`, and the shared repository-name contract. It does not create or look up ECR repositories. The shared `container-registry` root remains the ECR owner and must be deployed before development runtime infrastructure.

The future ECS log group ARN contract is:

- `/ecs/production-cloud-reliability/development/api`
- `/ecs/production-cloud-reliability/development/nginx`
- `/ecs/production-cloud-reliability/development/worker`

Stage 4I-B/C creates those log groups through the ECS module. IAM permissions are scoped to the log stream ARNs for those exact log groups.

## ECS Runtime

Stage 4I-B/C creates the development ECS runtime through the reusable `modules/ecs` module.

Development configuration:

- one Fargate-only ECS cluster
- enhanced Container Insights enabled
- Linux `X86_64` task runtime
- immutable image digest variables for API, Nginx, and worker
- API service desired count `1`
- worker service desired count `1`
- API task `512` CPU units and `1024` MiB memory
- worker task `256` CPU units and `512` MiB memory
- migration task `256` CPU units and `512` MiB memory
- API, Nginx, and worker log groups with 7-day retention
- CloudWatch Logs service-managed encryption
- ECS Exec disabled
- no Application Auto Scaling yet
- no Fargate Spot yet
- no customer-managed KMS key

The API task definition contains two essential containers: FastAPI and Nginx. FastAPI listens on port 8000 inside the task. Nginx listens on port 80 and proxies to `127.0.0.1:8000`. The ALB registers only the Nginx container on port 80.

`readonlyRootFilesystem` is not enabled in this stage. Nginx performs runtime template rendering and uses standard PID/cache/temp paths, and the Python images have not yet been validated with explicit writable mount points for every runtime temp path.

The API service runs only in application-private subnets, does not assign public IP addresses, and uses only the existing API security group.

The worker task definition contains one essential worker container, has no inbound ports, and has no load balancer integration. The worker service runs only in application-private subnets, does not assign public IP addresses, and uses only the existing worker security group.

Database connection settings are passed as discrete environment variables: `RUNTIME_MODE`, `DB_HOST`, `DB_PORT`, and `DB_NAME`. `DB_USERNAME` and `DB_PASSWORD` are injected from the RDS-managed Secrets Manager secret JSON keys. Terraform does not construct or store a password-bearing `DATABASE_URL`.

Linux Fargate platform version 1.4.0 or later is required for Secrets Manager JSON-key injection. Development uses `LATEST`, which must resolve to a compatible platform during deployment.

The worker receives `SQS_QUEUE_URL`, `ARTIFACT_BACKEND=s3`, `ARTIFACT_BUCKET_NAME`, `AWS_REGION`, and the validated lease/heartbeat settings. The SQS contract remains 60-second visibility timeout, max receive count `3`, long polling, and DLQ redrive from Stage 4D.

The one-off migration task definition uses the API image and command `python -m application.migrations`. It does not include Nginx and is not an ECS service. It should run later in application-private subnets with public IP disabled, using the existing worker security group because that network policy has no inbound access, HTTPS egress, and PostgreSQL egress to RDS.

Future release order:

1. Register new task definitions.
2. Run the one-off migration task.
3. Wait for the migration task to exit successfully.
4. Deploy or update API and worker services.

If migration fails, stop the release and do not roll out new application services automatically.

Rolling deployment circuit breakers are enabled for API and worker with rollback. Because desired count is `1`, a deployment can temporarily run two tasks and briefly increase Fargate cost.

## ECS Service Auto Scaling

Stage 4J adds AWS Application Auto Scaling for the API and worker ECS services through the reusable `modules/ecs-autoscaling` module.

Application Auto Scaling owns runtime `DesiredCount` after service creation. Terraform still creates and configures the ECS services, sets the initial desired count, and defines scalable min/max bounds. The ECS service resources ignore `desired_count` drift so Terraform does not fight scaling changes made by Application Auto Scaling.

Development capacity:

- API minimum capacity `1`
- API maximum capacity `4`
- worker minimum capacity `1`
- worker maximum capacity `4`

The worker does not scale to zero. The worker owns both transactional-outbox dispatch and SQS consumption. If worker desired count reached zero, API requests could keep committing durable outbox rows while no active process dispatches them to SQS.

API scaling uses target tracking on AWS-native ECS metrics:

- CPU target: 60 percent
- memory target: 70 percent

With multiple target-tracking policies, AWS scales out if any policy requires scale out. Scale in occurs only when all scale-in-enabled policies agree. This availability-biased behavior is intentional.

ALB request-count-per-target scaling is deferred until benchmark or load-test data establishes a defensible per-task request throughput target. No arbitrary request-per-task value is configured.

Worker scaling uses target tracking with CloudWatch metric math:

```text
AWS/SQS ApproximateNumberOfMessagesVisible
/
ECS/ContainerInsights RunningTaskCount
```

The queue name comes from `module.job_queue.queue_name`. The cluster and service names come from `module.ecs.cluster_name` and `module.ecs.worker_service_name`. The worker backlog-per-task target is a required deployment input with no fake default. It should be selected from acceptable queue wait time divided by average processing time, or equivalent workload-capacity reasoning.

Cooldowns:

- scale out: 60 seconds
- scale in: 300 seconds

Scale-in is deliberately conservative because messages may be in flight, workers may hold database leases, workers may be processing durable side effects, and rapid scale-in/out can increase churn.

The worker container has `stopTimeout = 120`, matching the current job-processing lease. This gives SIGTERM-aware shutdown the maximum Fargate grace window, but reliability does not depend on graceful shutdown alone. If a worker is force terminated, SQS visibility timeout, stale database leases, fencing tokens, and idempotent retry provide recovery.

ECS task scale-in protection is deferred. Current jobs are lightweight and already protected by SQS visibility, processing leases, fencing, idempotency, and the worker stop timeout. Task protection can be reconsidered if jobs become long-running or expensive to restart.

Deployment circuit breakers remain enabled for API and worker. Stage 4J does not change to blue/green, canary, or linear deployment. Application Auto Scaling suspends dynamic scale-in during ECS deployments while scale-out can continue, protecting availability during replacement.

Application Auto Scaling automatically owns the CloudWatch alarms created for target-tracking policies. General operational alarms, dashboards, and SLO alarms remain Stage 4L.

Stage 4J does not deploy Prometheus, Grafana, or OpenTelemetry. Autoscaling uses AWS-native CloudWatch metrics so scaling continues even if future Prometheus, Grafana, or OpenTelemetry components are unavailable.

Cost impact comes mainly from additional Fargate tasks during load, existing enhanced Container Insights telemetry, and CloudWatch metrics/log ingestion and storage. Development max capacity limits cost exposure. The worker minimum of `1` deliberately accepts baseline Fargate cost because the outbox dispatcher must remain available.

## Production Observability Foundation

Stage J-A adds the managed observability foundation for development runtime infrastructure.

Telemetry architecture:

- CloudWatch remains the AWS-native operational plane for infrastructure metrics, ECS enhanced Container Insights, ALB/RDS/SQS metrics, logs, alarms, dashboard, and AWS control-plane signals.
- Amazon Managed Service for Prometheus is the Prometheus-compatible backend for application and SRE metrics scraped by ADOT.
- Amazon Managed Grafana is the visualization and query plane for CloudWatch, AMP, and X-Ray.
- ADOT is the telemetry collection and export layer.
- AWS X-Ray is the distributed trace backend.

OpenTelemetry is not a log database. Structured stdout/stderr logs continue to flow through ECS `awslogs` into CloudWatch Logs. Logs are not double-shipped through OTLP in this stage.

Trace/log correlation:

- JSON logs retain `request_id` and `correlation_id`.
- Logs now include `trace_id` and `span_id` when an active OpenTelemetry span exists.
- When no span exists, those fields are null.

Prometheus metrics:

- API `/metrics` remains available for same-task ADOT scraping.
- API metrics use bounded labels such as method, route template, and status class.
- Worker metrics are exposed only on `127.0.0.1:9464` for the worker task's ADOT sidecar.
- Worker metrics use bounded labels such as result, operation, and job type.
- Metrics must not use UUIDs, customer IDs, request IDs, correlation IDs, raw URLs, S3 keys, or exception messages as labels.

Tracing:

- API inbound FastAPI requests are instrumented.
- psycopg database calls and boto3/botocore calls are instrumented where supported by OpenTelemetry.
- Worker spans cover outbox dispatch, SQS consume, job processing, and artifact write.
- Trace attributes must not include DB passwords, secret payloads, customer payloads, or full SQS message bodies.
- Sampling is configurable with parent-based trace ID ratio sampling; development defaults to `0.1`.

ECS ADOT sidecars:

- API task includes a non-essential ADOT collector sidecar.
- Worker task includes a non-essential ADOT collector sidecar.
- The migration task does not include an ADOT sidecar.
- ADOT collector image is required as an immutable digest input.
- OTLP listens only on localhost inside the task.
- API collector scrapes `127.0.0.1:8000/metrics`.
- Worker collector scrapes `127.0.0.1:9464`.
- Collector logs use existing API/worker CloudWatch log groups with stream prefix `otel`.

Task resource impact:

- API task remains `512` CPU / `1024` MiB by reallocating container CPU shares to API `320`, Nginx `128`, and ADOT `64`.
- Worker task remains `256` CPU / `512` MiB with worker `192` and ADOT `64`.
- ADOT memory reservation defaults to `128` MiB.
- These are development sizing choices, not production sizing conclusions.

IAM:

- ECS task roles receive telemetry export permissions because IAM is task-level, not container-level.
- API and worker task roles can remote-write only to the AMP workspace.
- API and worker task roles can write traces to X-Ray using the documented trace-write actions.
- X-Ray trace writes require wildcard resource scope.
- Application task roles do not receive broad CloudWatch, logs, SQS, S3, ECS, IAM, or KMS permissions for observability.
- Grafana uses a customer-managed read-only role trusted only by `grafana.amazonaws.com`.

Alarms:

- SNS topic is created for alarm notifications.
- No email or SMS subscription is created without an explicit endpoint.
- DLQ visible messages greater than zero is a critical alarm.
- ALB unhealthy targets greater than zero is a critical alarm.
- API 5XX rate, API p95 latency, queue oldest message age, RDS CPU, and RDS free storage thresholds are explicit required inputs.
- Missing data is treated as not breaching where no-traffic periods should not alarm.

Dashboard and queries:

- A development CloudWatch dashboard covers edge, ECS, queue, database, and autoscaling context.
- Logs Insights query definitions cover API errors, worker failures, correlation/request lookup, and trace ID lookup.

SLI/SLO contract:

- Measurable SLIs include API availability, API error rate, API latency, job success rate, job processing latency, queue wait/age, and DLQ occurrence.
- Final SLO values are not invented in this stage. Production targets must come from business requirements and measured performance.

Failure isolation:

- API health and readiness do not depend on AMP, Grafana, X-Ray, or ADOT.
- Worker processing does not depend on the metrics endpoint or telemetry export success.
- Autoscaling remains CloudWatch/AWS-native and does not depend on Prometheus, Grafana, or OpenTelemetry.

FinOps:

- AMP ingestion/query cost grows with sample volume and metric cardinality.
- Amazon Managed Grafana has workspace and active-user cost considerations.
- X-Ray trace volume creates trace storage/query cost.
- CloudWatch metrics, alarms, dashboards, Logs Insights, and log ingestion/storage create operational cost.
- Enhanced Container Insights emits additional telemetry.
- ADOT sidecars consume Fargate CPU/memory resources.
- No customer-managed KMS cost is introduced.
- VPC endpoint/private service routing remains deferred.

## Observability Operating Model

Stage J-B documents how the development observability foundation should be interpreted during deployment verification and incident response. It does not change Terraform resources, application code, IAM, networking, dashboards, alarms, or AWS state.

Operational documents:

- SLI/SLO contract: `docs/operations/observability/sli-slo-contract.md`
- alarm and query catalogue: `docs/operations/observability/alarm-and-query-catalogue.md`
- metric/log/trace workflows: `docs/operations/observability/triage-workflows.md`
- drills and checklists: `docs/operations/observability/drills-and-checklists.md`
- incident runbooks: `docs/operations/runbooks/`

Development remains the first environment for proving ADOT to AMP remote write, ADOT to X-Ray export, Amazon Managed Grafana datasource connectivity, CloudWatch alarm behavior under real failures, ECS rollback telemetry, and notification delivery after a real subscriber is configured.

No final SLO target or production threshold is declared in development documentation. Those values require business requirements, observed traffic, load-test evidence, and an agreed error-budget policy.

## Selective Private AWS-Service Routing

Stage K adds one regional S3 Gateway VPC Endpoint to the development VPC.

Scope:

- NAT Gateway remains in place.
- Application-private default routes to NAT remain unchanged.
- The S3 Gateway Endpoint is associated only with application-private route tables.
- Public route tables and database-private route tables are not associated.
- No interface endpoints, endpoint security groups, endpoint ENIs, subnet endpoint associations, IAM changes, KMS changes, or bucket policy changes are added.

Routing after Stage K:

```text
same-Region S3 traffic
  -> AWS-managed S3 prefix-list route
  -> S3 Gateway Endpoint

other HTTPS egress
  -> 0.0.0.0/0
  -> NAT Gateway
  -> Internet Gateway
  -> external Internet or public AWS service endpoint
```

The S3 prefix-list route is more specific than `0.0.0.0/0`, so S3 traffic uses the endpoint while external Internet and deferred AWS service traffic continues through NAT.

Artifact path:

- Worker artifact access remains scoped to `reports/*`.
- The report key contract remains `reports/{job_id}/{report_id}.csv`.
- Existing worker IAM remains the primary authorization boundary.
- The endpoint policy is an additional network-path authorization layer.

ECR starport path:

- The endpoint policy also permits `s3:GetObject` on `arn:aws:s3:::prod-${var.aws_region}-starport-layer-bucket/*`.
- This is required because ECR image layers use the regional S3 starport bucket.
- Stage K does not make ECR fully private because ECR API and ECR DKR still require their own interface endpoints, which are deferred.

NAT remains necessary for:

- external SaaS and partner APIs
- SQS
- ECR API
- ECR DKR
- Secrets Manager
- CloudWatch Logs
- AMP and X-Ray service APIs where applicable

FinOps:

- S3 Gateway Endpoint has no additional endpoint hourly or gateway-endpoint data-processing charge.
- Non-S3 traffic can still incur existing NAT hourly and data-processing cost.
- Paid interface endpoints should be evaluated later against measured NAT traffic, security requirements, and availability goals.

Production review triggers:

- NAT processed-byte cost materially increases.
- compliance requires private AWS API paths.
- production removes broad Internet egress.
- NAT availability becomes unacceptable.
- telemetry or CloudWatch traffic justifies endpoint economics.
- artifact bucket access must be restricted by `aws:sourceVpce`.

## Account Security Audit Relationship

Stage L is intentionally owned outside the development root.

The CloudTrail audit plane is account/control-plane governance, so its Terraform owner is `infrastructure/shared/security-audit` with intended state key:

```text
shared/security-audit/terraform.tfstate
```

Development runtime resources remain in this root. Do not add a separate development CloudTrail trail for the same account-level audit responsibility.

## Public Edge

Stage 4G creates the deployment-ready public edge through reusable `modules/acm-dns` and `modules/alb`.

Development requires two non-secret inputs:

- `application_domain_name`, for example `app.chisomeze.online`
- `route53_zone_id`, the existing Route 53 public hosted-zone ID

The domain `chisomeze.online` was purchased through Namecheap. Terraform does not create the hosted zone in this stage. Before deployment, create or identify the Route 53 public hosted zone for `chisomeze.online` and configure the Namecheap domain to use the Route 53 nameservers.

Edge flow:

```text
client
  -> Route 53 A alias
  -> internet-facing ALB
  -> HTTPS 443 termination
  -> API target group TCP 80
  -> future Nginx container
```

Development configuration:

- ACM public certificate for the exact application FQDN
- DNS validation records in the existing Route 53 hosted zone
- certificate validation resource used by the HTTPS listener
- Route 53 A alias to the ALB with target health evaluation
- internet-facing ALB across both public subnets
- existing ALB security group only
- HTTP listener on port 80 that redirects to HTTPS with HTTP 301
- HTTPS listener on port 443 that forwards to the API target group
- modern TLS policy `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09`
- target group protocol HTTP, port 80, target type `ip`
- health check `GET /health`
- deregistration delay 30 seconds
- invalid-header dropping enabled
- HTTP/2 enabled
- ALB deletion protection disabled for development teardown
- dedicated ALB access-log bucket with 30-day retention

The ALB health check uses `/health`, not `/ready`, because ALB target health should confirm that the task can answer traffic. A temporary PostgreSQL dependency failure reported by `/ready` should not cause the load balancer to mark every task unhealthy and churn replacements.

Worker ECS tasks are not behind this ALB. FastAPI port 8000, PostgreSQL port 5432, and SSH are not exposed through the edge.

ALB access logs are stored in a dedicated private S3 bucket, not the application artifact bucket. The log bucket uses full Public Access Block, `BucketOwnerEnforced`, SSE-S3 with `AES256`, versioning, finite lifecycle retention, TLS-only deny policy, and the current ALB log-delivery service principal.

WAF is intentionally not implemented in this stage. It remains required before final edge sign-off because managed rule selection, logging, and cost posture belong to a dedicated security-edge stage.

The ALB will provide forwarded request headers such as `X-Forwarded-For` and `X-Forwarded-Proto`. Future Nginx/FastAPI configuration must process proxy headers deliberately.

## Web Application Firewall

Stage 4H creates a REGIONAL AWS WAFv2 Web ACL through the reusable `modules/waf` module and associates it only with the Stage 4G ALB ARN.

Development configuration:

- Web ACL default action `ALLOW`
- `AWSManagedRulesCommonRuleSet`
- `AWSManagedRulesKnownBadInputsRuleSet`
- `AWSManagedRulesSQLiRuleSet`
- `AWSManagedRulesAmazonIpReputationList`
- managed rule groups enforce their normal blocking behavior through `override_action = none`
- IP-based rate limit blocks requests above 2000 requests per IP over 300 seconds
- Web ACL, managed rules, and rate-limit rule all enable CloudWatch metrics and sampled requests
- dedicated WAF CloudWatch log group named with the required `aws-waf-logs-` prefix
- 30-day WAF log retention
- WAF log redaction for `Authorization` and `Cookie` headers
- no customer-managed KMS key
- no Shield Advanced
- no Bot Control, Fraud Control, ATP, CAPTCHA, or Challenge
- no blanket Anonymous IP block

Managed rule group versions are required development variables. Before deployment, query AWS for currently supported versions and pass them explicitly. This avoids invented versions while keeping the Web ACL reproducible.

WAF rate limiting is an application-layer request guardrail. It is not a replacement for AWS Shield. Shield Standard is AWS baseline protection for supported resources; Shield Advanced is not implemented because it requires explicit business and cost approval.

Applications must not place secrets in URL paths or query strings. WAF logging redacts selected headers, but request metadata remains sensitive operational data and log access must stay restricted.
