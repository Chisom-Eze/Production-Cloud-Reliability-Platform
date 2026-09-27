# Development Deployment Input Contract

## 1. Purpose

Authenticated deployment must not turn required Terraform values into an untracked collection of operator choices. Every input needs a named source of truth, an owner, a delivery mechanism, and a lifecycle so a reviewed plan can be reproduced and explained.

This contract separates stable development configuration, values discovered from AWS and then pinned, immutable release outputs, external dependency pins, Terraform-generated values, and AWS-managed secrets. It also freezes the first-deployment order and records the ECS migration blocker that prevents a full development apply today.

Credentials are not ordinary deployment inputs. GitHub Actions obtains short-lived AWS credentials through GitHub OIDC and an environment-scoped IAM role. Database credentials remain AWS-managed and are injected into ECS from Secrets Manager. Neither credential path belongs in Terraform variable files, GitHub configuration values, release manifests, logs, or artifacts.

## 2. Input Classification Model

| Source-of-truth class | Ownership and intended use |
| --- | --- |
| Bootstrap Terraform output | Control-plane values created by the bootstrap root, such as the Terraform state bucket and GitHub OIDC role ARNs. A workflow may consume an explicitly exported output or corresponding protected GitHub Environment configuration; bootstrap state is not read casually by application deployment. |
| Repository-controlled development configuration | Stable, non-secret development policy reviewed in Git, such as the application FQDN, scaling target, and alarm thresholds. Changes follow normal code review and are not improvised during a release. |
| GitHub Environment non-secret configuration | Environment-scoped workflow configuration, such as the ARN of the OIDC role a job is allowed to assume. It is not a store for application image digests, passwords, or ad-hoc Terraform values. |
| Authenticated AWS capability lookup followed by explicit pinning | Values that must be discovered from the target AWS account or service, then recorded explicitly for review and repeatability. Discovery does not authorize automatically following `latest` or whichever value AWS returns during deployment. |
| Container release pipeline output | Immutable image repositories and digests produced by building, scanning, and publishing one release. These values flow through the release manifest and are not manually maintained as permanent GitHub variables. |
| External dependency pin | A reviewed immutable reference for a third-party runtime dependency. The ADOT collector belongs here and must use a digest, not a mutable tag. |
| Terraform runtime/module output | Values created within the Terraform graph and passed directly between roots/modules or resources, such as subnet IDs, target group ARNs, queue URLs, database endpoints, and the RDS-managed secret ARN. They are not duplicated as operator inputs. |
| AWS-managed secret | Secret material generated and stored by AWS, retrieved at runtime only by an authorized workload. The RDS master password remains in Secrets Manager and reaches ECS through secret injection. |

## 3. Complete Development Input Inventory

`infrastructure/environments/development/variables.tf` contains 16 variables without defaults. All are required by the development root. A variable description that contains an example is not a resolved value.

| Terraform input | Required? | Default? | Source of truth | Delivery mechanism | Secret? | Lifecycle | Currently resolved? | Required before |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `application_domain_name` | Yes | None | Repository-controlled development configuration | Reviewed, non-secret development application input supplied to Terraform | No | Stable environment configuration; change only with deliberate DNS/application review | No; `app.chisomeze.online` appears only as an example | Authenticated development plan |
| `route53_zone_id` | Yes | None | Authenticated AWS capability lookup followed by explicit pinning | Discover in the target account, verify domain ownership/scope, then record as reviewed development configuration | No | Stable until the hosted zone is deliberately replaced | No | Authenticated development plan |
| `waf_common_rule_set_version` | Yes | None | Authenticated AWS capability lookup followed by explicit pinning | Query AWS for supported `AWSManagedRulesCommonRuleSet` versions, review, then pin in development configuration | No | Upgrade through an explicit reviewed change; never follow newest automatically | No | Authenticated development plan |
| `waf_known_bad_inputs_rule_set_version` | Yes | None | Authenticated AWS capability lookup followed by explicit pinning | Query AWS for supported `AWSManagedRulesKnownBadInputsRuleSet` versions, review, then pin in development configuration | No | Upgrade through an explicit reviewed change; never follow newest automatically | No | Authenticated development plan |
| `waf_sqli_rule_set_version` | Yes | None | Authenticated AWS capability lookup followed by explicit pinning | Query AWS for supported `AWSManagedRulesSQLiRuleSet` versions, review, then pin in development configuration | No | Upgrade through an explicit reviewed change; never follow newest automatically | No | Authenticated development plan |
| `waf_ip_reputation_rule_set_version` | Yes | None | Authenticated AWS capability lookup followed by explicit pinning | Query AWS for supported `AWSManagedRulesAmazonIpReputationList` versions, review, then pin in development configuration | No | Upgrade through an explicit reviewed change; never follow newest automatically | No | Authenticated development plan |
| `api_image_uri` | Yes | None | Container release pipeline output | Release manifest supplies `repository@sha256:digest` to the deployment workflow as an ephemeral Terraform input | No | Unique per approved release; immutable after publication | No | Authenticated development plan and apply |
| `nginx_image_uri` | Yes | None | Container release pipeline output | Release manifest supplies `repository@sha256:digest` to the deployment workflow as an ephemeral Terraform input | No | Unique per approved release; immutable after publication | No | Authenticated development plan and apply |
| `worker_image_uri` | Yes | None | Container release pipeline output | Release manifest supplies `repository@sha256:digest` to the deployment workflow as an ephemeral Terraform input | No | Unique per approved release; immutable after publication | No | Authenticated development plan and apply |
| `adot_collector_image_uri` | Yes | None | External dependency pin | A reviewed dependency record supplies an immutable `repository@sha256:digest` reference as a development application input | No | Changed only after dependency review, compatibility validation, and security review | No | Authenticated development plan |
| `worker_backlog_per_task_target` | Yes | None | Repository-controlled development configuration | Reviewed, non-secret development application input supplied to Terraform | No | Tune from measured acceptable queue wait time and processing time; changes are reviewed | No | Authenticated development plan |
| `api_5xx_error_rate_alarm_percent` | Yes | None | Repository-controlled development configuration | Reviewed, non-secret development application input supplied to Terraform | No | Provisional first value, then tune from observed service behavior through review | No | Authenticated development plan |
| `api_p95_latency_alarm_seconds` | Yes | None | Repository-controlled development configuration | Reviewed, non-secret development application input supplied to Terraform | No | Provisional first value, then tune from observed service behavior through review | No | Authenticated development plan |
| `queue_oldest_message_age_alarm_seconds` | Yes | None | Repository-controlled development configuration | Reviewed, non-secret development application input supplied to Terraform | No | Provisional first value, then tune against queue SLO and processing behavior through review | No | Authenticated development plan |
| `rds_cpu_alarm_percent` | Yes | None | Repository-controlled development configuration | Reviewed, non-secret development application input supplied to Terraform | No | Provisional first value, then tune from observed database behavior through review | No | Authenticated development plan |
| `rds_free_storage_alarm_bytes` | Yes | None | Repository-controlled development configuration | Reviewed, non-secret development application input supplied to Terraform | No | Provisional first value, then tune against storage growth and response time through review | No | Authenticated development plan |

### Stable Development Configuration

The application FQDN, worker backlog-per-task target, and alarm thresholds are environment policy. They must be deterministic and reviewable. They should be supplied from a version-controlled, non-secret development configuration contract rather than typed ad hoc into a workflow run. The exact file/serialization mechanism is a later implementation choice; this document does not create one or assign values.

Ownership of `chisomeze.online` does not by itself resolve `application_domain_name`. The exact application FQDN still requires an explicit decision.

### AWS-Derived Configuration

The Route 53 hosted-zone ID and all four AWS WAF managed-rule versions require authenticated discovery in `us-east-1` or the applicable global service scope. Discovery is followed by review and an explicit pin. A deployment must not ask AWS for the newest WAF version and silently adopt it during plan or apply.

### Release-Produced Configuration

The API, worker, and project-owned Nginx images follow this contract:

```text
build once
  -> security scan
  -> publish immutable Git SHA tag
  -> resolve ECR digest
  -> record release manifest
  -> deploy repository@sha256:digest
```

The release process owns these three image values. They must not become manually maintained GitHub repository or Environment variables. Terraform receives them from the selected immutable release manifest at workflow runtime.

### External Runtime Dependency

The ADOT collector is not built by this repository's application image release. Its image must be selected through explicit dependency review and pinned by digest. A mutable `latest` or version-only tag is insufficient for deployment reproducibility.

### Secrets

RDS uses `manage_master_user_password = true`. Terraform passes the RDS-managed Secrets Manager ARN to the ECS module, and ECS injects the required JSON secret values into containers at runtime. The database password must never pass through GitHub variables, workflow inputs, Terraform variable files, release manifests, plan artifacts, or logs.

## 4. Release Manifest Contract

The future release pipeline must emit an immutable manifest that binds one source revision and one build/run to the exact images approved for deployment. The conceptual schema is:

```json
{
  "source_git_sha": "<full-git-sha>",
  "build_run_id": "<immutable-build-or-run-identifier>",
  "images": {
    "api": {
      "repository": "<api-ecr-repository-uri>",
      "digest": "sha256:<digest>"
    },
    "worker": {
      "repository": "<worker-ecr-repository-uri>",
      "digest": "sha256:<digest>"
    },
    "nginx": {
      "repository": "<nginx-ecr-repository-uri>",
      "digest": "sha256:<digest>"
    }
  }
}
```

The Git SHA tag provides traceability at publication time, while the digest is the deployment identity. The deployment workflow must select one approved manifest, validate its shape and provenance, compose each `repository@digest` Terraform input, and preserve the manifest with deployment evidence. Rebuilding the same Git SHA creates a different candidate release and therefore requires a new manifest and review.

The manifest format, storage location, signing/attestation method, retention, and workflow implementation remain future design work. This stage defines the contract only.

## 5. Terraform Backend/Input Separation

Backend inputs locate and protect Terraform state:

```text
state bucket
state key
AWS region
use_lockfile = true
```

For the development root, the state key is `environments/development/terraform.tfstate`. Backend configuration is supplied explicitly by the authenticated workflow before planning or applying. Native S3 locking is used; there is no DynamoDB locking table.

Application inputs describe the infrastructure and release to plan, including the FQDN, hosted-zone ID, WAF pins, image digests, scaling target, and alarm thresholds. They enter Terraform only after backend initialization and do not belong in backend configuration.

The workflow can supply known backend coordinates directly or derive stable control-plane values from approved bootstrap outputs/configuration. This does not justify committing populated backend files for every environment. Backend files can accidentally expose account-specific details, create local/workflow drift, or encourage operators to treat backend and application values as one configuration surface. Credentials are never backend inputs; the workflow obtains short-lived credentials through OIDC.

## 6. First AWS Development Deployment Sequence

The first deployment must follow this dependency order. A failed hard gate stops the sequence; later steps do not run.

1. Verify the bootstrap state bucket, native S3 locking, GitHub OIDC provider, exact environment trust, and role outputs.
2. Complete and verify FinOps guardrails, including the existing account-level AWS Budget alert and the development teardown runbook.

**Hard gate A:** The control plane and cost operating model are evidenced before any deployment authority is used.

3. Implement least-privilege, separately owned deployment/apply/release IAM. Keep plan, infrastructure mutation, image publication, and ECS release capabilities separated.

**Hard gate B:** No shared or development apply proceeds until the intended identity has only the permissions required for that operation.

4. Run an authenticated apply of `infrastructure/shared/container-registry`.
5. Run an authenticated apply of `infrastructure/shared/security-audit`.

**Hard gate C:** ECR repositories and audit controls must exist and be verified before image publication.

6. Build and security-scan the API, worker, and Nginx images once.
7. Push immutable Git-SHA-tagged images to ECR.
8. Capture the ECR digest of each published image in one immutable release manifest.

**Hard gate D:** Any failed build or security gate stops publication/deployment. Deployment uses the captured digests, never `latest`, mutable tags, or rebuilt substitutes.

9. Resolve and pin development configuration: exact FQDN, Route 53 zone ID, reviewed WAF versions, ADOT digest, worker target, and alarm thresholds.
10. Run an authenticated Terraform plan for `infrastructure/environments/development` with the selected release manifest and reviewed development configuration.
11. Review and approve the complete plan and its identity, backend key, input provenance, and expected changes.

**Hard gate E:** Missing, fabricated, mutable, or unreviewed inputs stop planning/approval. A successful plan is not authorization to bypass the ECS sequencing blocker.

12. Apply the development foundation only after ECS rollout sequencing has been corrected so service updates cannot precede migration success.
13. Run the one-off migration task using the approved task-definition revision.
14. Wait for the migration task to stop.
15. Verify that the migration container exited successfully and preserve its logs/task evidence.
16. If migration fails, **STOP THE RELEASE**. Do not update either API or worker service.

**Hard gate F:** A verified zero/success migration result is mandatory before service mutation. Timeout, task-launch failure, missing evidence, or non-zero exit is failure.

17. Only after migration success, update the API and worker services to the approved task-definition revision.
18. Wait for both ECS services to reach stability and verify expected task counts and target health.

**Hard gate G:** Unstable services, failed tasks, unhealthy targets, or unexpected revisions stop acceptance and trigger diagnosis/rollback according to the future release runbook.

19. Perform live synchronous and asynchronous verification.
20. Preserve the plan approval, release manifest, image digests, migration result, service rollout evidence, health checks, logs, queue evidence, report artifact, and durable job state.

**Hard gate H:** The deployment is accepted only when the complete acceptance contract below is evidenced. Terraform apply success by itself is insufficient.

There is no local `terraform apply` path. Deployment runs GitHub Actions -> GitHub OIDC -> AWS IAM -> Terraform/AWS.

## 7. ECS Release Blocker

The current ECS implementation directly connects Terraform-owned services to Terraform-owned task definitions:

```text
aws_ecs_service.api.task_definition
  = aws_ecs_task_definition.api.arn

aws_ecs_service.worker.task_definition
  = aws_ecs_task_definition.worker.arn
```

Consequently, one Terraform apply can register new task definitions and update the API/worker services as part of the same graph. It cannot enforce this required operational sequence:

```text
register task definitions
  -> run migration
  -> wait
  -> verify successful exit
  -> update services
```

The first full development apply must not proceed while this ordering cannot be enforced. In particular, plan approval does not waive the blocker.

The intended ownership boundary for later design is:

**Terraform owns:**

- stable ECS infrastructure;
- ECS cluster;
- task-definition definitions/registration inputs;
- IAM roles and policies;
- autoscaling;
- networking;
- service infrastructure.

**Release orchestration owns:**

- selection of the approved task-definition revision;
- one-off migration invocation;
- waiting for task completion;
- verification and preservation of the migration result;
- API and worker service update only after migration success;
- service-stability verification and release evidence.

The exact Terraform lifecycle mechanism, service/task-definition ownership split, state implications, and release command/API mechanism remain an implementation decision. They must be designed and reviewed in a later task rather than guessed here.

## 8. Deployment Acceptance Contract

A development deployment is accepted only when evidence proves both complete application paths.

Synchronous path:

```text
Route 53
  -> WAF
  -> ALB HTTPS
  -> Nginx
  -> FastAPI
  -> RDS
```

Required evidence includes successful `/health` and `/ready` behavior, healthy ALB targets, expected TLS/DNS routing, and correlated application/database log evidence.

Asynchronous path:

```text
FastAPI
  -> PostgreSQL transaction
  -> job + outbox
  -> worker dispatcher
  -> SQS
  -> worker consumer
  -> S3 artifact
  -> PostgreSQL durable completion
```

Required evidence includes the accepted API request/job identifier, committed job and outbox state, queue publication/consumption behavior, worker logs, generated S3 report artifact, and durable PostgreSQL completion state. Retry/visibility behavior must not produce an incorrect terminal result.

Acceptance also requires:

- `/health` succeeds for the intended liveness contract;
- `/ready` proves required dependencies are ready;
- ALB target health is healthy for the deployed API revision;
- CloudWatch logs show the expected API, Nginx, worker, migration, and observability behavior without unexplained fatal errors;
- queue depth, age, retry, and DLQ behavior are consistent with the test;
- the generated report artifact exists at the expected key and is retrievable by the authorized path;
- the job reaches durable successful completion in PostgreSQL;
- API and worker services are stable on the approved release revision.

Terraform plan or apply success alone is not deployment acceptance.

## 9. Explicit Non-Goals

This documentation task does not:

- implement Terraform apply;
- implement a release workflow or release manifest;
- modify ECS lifecycle or service ownership;
- invent the application FQDN or any other domain value;
- invent a Route 53 hosted-zone ID;
- invent WAF managed-rule versions;
- invent worker scaling or alarm thresholds;
- invent image repositories or digests;
- add KMS resources;
- add long-lived AWS credentials;
- grant `AdministratorAccess`;
- create staging;
- create production.

## 10. Remaining M-B3 Exit Criteria

M-B3 is closed only when all of the following statements are true:

- Every required, no-default development Terraform input is present in the inventory with provenance, delivery mechanism, sensitivity, lifecycle, resolution status, and deadline.
- Stable configuration, AWS-derived pins, release-produced image references, the external ADOT pin, Terraform outputs, and AWS-managed secrets are kept in their documented ownership classes.
- The immutable release-manifest contract is documented without pretending it has been implemented.
- Backend coordinates and Terraform application inputs are explicitly separated.
- The 20-step first-development deployment sequence and its hard stop gates are frozen and reviewable.
- The current migration-before-service-rollout blocker and the intended Terraform/release ownership boundary are documented.
- The synchronous and asynchronous deployment acceptance evidence is defined, and Terraform success alone is explicitly insufficient.
- Every currently unresolved value remains visibly unresolved; no deployment value has been fabricated.

Closing this documentation stage does not authorize the first full development apply. That apply remains blocked until the ECS release sequencing mechanism is designed, implemented, statically validated, and proven capable of stopping before API/worker service updates when migration fails.
