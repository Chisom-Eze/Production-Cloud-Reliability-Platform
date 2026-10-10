# Development Deployment Input Contract

## 1. Purpose

Authenticated deployment must not turn required Terraform values into an untracked collection of operator choices. Every input needs a named source of truth, an owner, a delivery mechanism, and a lifecycle so a reviewed plan can be reproduced and explained.

This contract separates stable development configuration, values discovered from AWS and then pinned, immutable release outputs, external dependency pins, Terraform-generated values, and AWS-managed secrets. GitHub Environment Variables in `development-plan` deliver the 15 reviewed non-secret inputs to the permanent Plan workflow. It also records the first-deployment order, the implemented ECS bootstrap gate, and the remaining operator-supplied values.

Credentials are not ordinary deployment inputs. GitHub Actions obtains short-lived AWS credentials through GitHub OIDC and an environment-scoped IAM role. Database credentials remain AWS-managed and are injected into ECS from Secrets Manager. Neither credential path belongs in Terraform variable files, GitHub configuration values, release manifests, logs, or artifacts.

## 2. Input Classification Model

| Source-of-truth class | Ownership and intended use |
| --- | --- |
| Bootstrap Terraform output | Control-plane values created by the bootstrap root, such as the Terraform state bucket and GitHub OIDC role ARNs. A workflow may consume an explicitly exported output or corresponding protected GitHub Environment configuration; bootstrap state is not read casually by application deployment. |
| Reviewed development configuration | The initial application FQDN, scaling target, alarm thresholds, and WAF pins are recorded in this contract. Operators populate the matching `development-plan` Environment Variables and review changes before planning. |
| GitHub Environment non-secret configuration | `development-plan` Environment Variables are the input source consumed by the Plan job. The explicit mapping below includes reviewed development configuration and frozen immutable image references. These variables never contain credentials or passwords. The OIDC role ARN remains separate control-plane configuration. |
| Authenticated AWS capability lookup followed by explicit pinning | Values that must be discovered from the target AWS account or service, then recorded explicitly for review and repeatability. Discovery does not authorize automatically following `latest` or whichever value AWS returns during deployment. |
| Container release pipeline output | Frozen image repositories and digests identify the approved API, worker, and Nginx release. Operators copy those approved references into the matching Environment Variables; selecting another release requires updating those references and reviewing a new plan. |
| External dependency pin | A reviewed immutable reference for a third-party runtime dependency. The ADOT collector belongs here and must use a digest, not a mutable tag. |
| Terraform runtime/module output | Values created within the Terraform graph and passed directly between roots/modules or resources, such as subnet IDs, target group ARNs, queue URLs, database endpoints, and the RDS-managed secret ARN. They are not duplicated as operator inputs. |
| AWS-managed secret | Secret material generated and stored by AWS, retrieved at runtime only by an authorized workload. The RDS master password remains in Secrets Manager and reaches ECS through secret injection. |

## 3. Complete Development Input Inventory

`infrastructure/environments/development/variables.tf` contains exactly these 15 required variables without defaults. Populate all 15 as **Variables**, not Secrets, in the GitHub Environment **development-plan**. None is a `workflow_dispatch` input. The table records initial reviewed values; it does not claim that GitHub configuration has already been populated.

| Terraform variable | Terraform environment variable | GitHub Environment Variable | Initial reviewed value | Source / ownership | Changes per release? |
| --- | --- | --- | --- | --- | --- |
| `application_domain_name` | `TF_VAR_application_domain_name` | `APPLICATION_DOMAIN_NAME` | `app.chisomeze.online` | Reviewed development DNS policy / operator | No; deliberate DNS change only |
| `route53_zone_id` | `TF_VAR_route53_zone_id` | `ROUTE53_ZONE_ID` | Operator must populate from the existing `shared/dns` output `hosted_zone_id` | Shared authoritative DNS root / operator verifies zone ownership and delegation | No; only if the zone changes |
| `api_image_uri` | `TF_VAR_api_image_uri` | `API_IMAGE_URI` | `964117916184.dkr.ecr.us-east-1.amazonaws.com/production-cloud-reliability-api@sha256:0eb44900e206ddfc3d59709d353e7142ec8c2ff63b4a42ad64be8799b26122c3` | Operator-supplied frozen release image / release owner | Yes; use the approved release digest |
| `worker_image_uri` | `TF_VAR_worker_image_uri` | `WORKER_IMAGE_URI` | `964117916184.dkr.ecr.us-east-1.amazonaws.com/production-cloud-reliability-worker@sha256:bfab48e9df940193d47391e5c12077d8745b08b72a03b598a4465009dfd7231c` | Operator-supplied frozen release image / release owner | Yes; use the approved release digest |
| `nginx_image_uri` | `TF_VAR_nginx_image_uri` | `NGINX_IMAGE_URI` | `964117916184.dkr.ecr.us-east-1.amazonaws.com/production-cloud-reliability-nginx@sha256:848b60479af8a4e096bc7dba50f0591c5fe336cae0b1309ab52c92097d6f5ed3` | Operator-supplied frozen release image / release owner | Yes; use the approved release digest |
| `adot_collector_image_uri` | `TF_VAR_adot_collector_image_uri` | `ADOT_COLLECTOR_IMAGE_URI` | Operator must populate the full `public.ecr.aws/aws-observability/aws-otel-collector@sha256:<resolved-digest>` URI using the already validated immutable digest | Reviewed external dependency / operator; exact digest not supplied here | No; only after dependency review |
| `waf_common_rule_set_version` | `TF_VAR_waf_common_rule_set_version` | `WAF_COMMON_RULE_SET_VERSION` | `Version_1.23` | Operator-discovered AWS recommended default / security owner | No; review before expiration |
| `waf_known_bad_inputs_rule_set_version` | `TF_VAR_waf_known_bad_inputs_rule_set_version` | `WAF_KNOWN_BAD_INPUTS_RULE_SET_VERSION` | `Version_1.26` | Operator-discovered AWS recommended default / security owner | No; review before expiration |
| `waf_sqli_rule_set_version` | `TF_VAR_waf_sqli_rule_set_version` | `WAF_SQLI_RULE_SET_VERSION` | `Version_1.3` | Operator-discovered AWS recommended default / security owner | No; review before expiration |
| `worker_backlog_per_task_target` | `TF_VAR_worker_backlog_per_task_target` | `WORKER_BACKLOG_PER_TASK_TARGET` | `10` | Initial development capacity policy / operator | No; tune through review |
| `api_5xx_error_rate_alarm_percent` | `TF_VAR_api_5xx_error_rate_alarm_percent` | `API_5XX_ERROR_RATE_ALARM_PERCENT` | `5` (percent) | Initial API error alarm policy / operator | No; tune through review |
| `api_p95_latency_alarm_seconds` | `TF_VAR_api_p95_latency_alarm_seconds` | `API_P95_LATENCY_ALARM_SECONDS` | `2` (seconds) | Initial API latency alarm policy / operator | No; tune through review |
| `queue_oldest_message_age_alarm_seconds` | `TF_VAR_queue_oldest_message_age_alarm_seconds` | `QUEUE_OLDEST_MESSAGE_AGE_ALARM_SECONDS` | `120` (seconds) | Initial SQS age alarm policy / operator | No; tune through review |
| `rds_cpu_alarm_percent` | `TF_VAR_rds_cpu_alarm_percent` | `RDS_CPU_ALARM_PERCENT` | `80` (percent) | Initial RDS CPU alarm policy / operator | No; tune through review |
| `rds_free_storage_alarm_bytes` | `TF_VAR_rds_free_storage_alarm_bytes` | `RDS_FREE_STORAGE_ALARM_BYTES` | `5368709120` (bytes; 5 GiB) | Initial RDS storage alarm policy / operator | No; tune through review |

Enter numeric values as their plain numbers, without unit labels. `ecs_services_enabled` is **not** part of this Environment Variable contract. Its Terraform default remains `false`, and the development Plan workflow writes `TF_VAR_ecs_services_enabled=false` as a fixed code-controlled value. There is no GitHub variable mapping or dispatch input for that flag. Enabling initial services requires a separate reviewed workflow/configuration change after successful migration evidence.

### Stable Development Configuration

The application FQDN, worker backlog-per-task target, and alarm thresholds are environment policy. Their initial reviewed values are recorded above and supplied through the explicit `development-plan` Environment Variable mapping. Review and document changes before planning; they are not ad-hoc dispatch inputs. The chosen application FQDN is `app.chisomeze.online`.

### AWS-Derived Configuration

The Route 53 hosted-zone ID and three versioned AWS WAF managed groups require authenticated discovery in `us-east-1` or the applicable global service scope. The hosted zone is owned by `shared/dns`; use its verified `hosted_zone_id` output after deployment and delegation. Discovery is followed by review and an explicit pin. A deployment must not ask AWS for the newest WAF version and silently adopt it during plan or apply.

The operator's authoritative AWS discovery supplied these current-default pins:

```hcl
waf_common_rule_set_version           = "Version_1.23"
waf_known_bad_inputs_rule_set_version = "Version_1.26"
waf_sqli_rule_set_version             = "Version_1.3"
```

SQLi intentionally uses `Version_1.3`, not the numerically higher `Version_2.5`. These reviewed pins must be revisited before expiration. `AWSManagedRulesAmazonIpReputationList` is not versioned; its Terraform statement intentionally omits `version`, and neither the module nor the development root accepts a version input for it.

### GitHub Environment Input Delivery

`.github/workflows/terraform-plan-development.yml` maps the 15 Environment Variables through explicit step-level `TF_VAR_*` entries only when the selected root is `environments/development`. Shared roots skip this step and do not require any of these development variables. Values are read through `vars`, not `secrets`, and are not interpolated into shell code or evaluated dynamically.

Before AWS authentication or Terraform planning, the step checks every value for presence, reports missing GitHub variable names without printing values or dumping the environment, and checks all four image references against the immutable digest form already required by Terraform. Multiline values are rejected before writing the validated inputs to `GITHUB_ENV`, so they cannot inject another environment assignment. WAF versions must be non-empty; supported-version decisions and the reviewed pins remain in their documented ownership rather than a second workflow allowlist. Terraform's existing variable validations remain the final value contract.

The step preserves validated `TF_VAR_*` values for the later Plan process and fixes `TF_VAR_ecs_services_enabled=false`. Updating GitHub values after a plan is produced cannot alter that saved binary plan. Apply receives no new `TF_VAR_*` mapping, never re-plans, and applies only the downloaded artifact after the existing run-attempt, SHA, metadata, and digest verification.

The operator must populate all 15 variables in `development-plan`; specifically, `ROUTE53_ZONE_ID` and the exact digest in `ADOT_COLLECTOR_IMAGE_URI` remain operator-supplied. Source implementation is not evidence of a completed GitHub configuration or successful authenticated run.

### Provider Lockfile Preparation

The development root requires Terraform `>= 1.10.0` and only `hashicorp/aws ~> 6.0`, matching the existing shared-root convention and its development modules. No shared-root or development `.terraform.lock.hcl` is present in this checkout, so an existing file cannot be certified for exact reuse here. A shared lockfile with a compatible AWS selection and the required platform checksums could be reusable, but generate or verify the lock in the development root rather than assuming that matching constraints prove a particular file is suitable.

Recommended operator commands in WSL, not executed by this source change:

```bash
cd /home/chisom/projects/prod-sre/infrastructure/environments/development
terraform init -backend=false -input=false
terraform providers lock -platform=linux_amd64 -platform=windows_amd64
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
```

Review the selected provider and checksums, then commit the development `.terraform.lock.hcl`. These preparation commands do not initialize the remote backend or create a plan. The permanent workflows retain `-lockfile=readonly`; this patch neither generates nor edits any lockfile.

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

The release process owns these three image identities. For this reviewed first-deployment handoff, operators populate `API_IMAGE_URI`, `WORKER_IMAGE_URI`, and `NGINX_IMAGE_URI` in `development-plan` with the exact frozen references above. Those references change only when another approved release is selected. Future automated manifest delivery can replace that handoff through a separate reviewed change; this workflow does not claim to fetch or verify a release manifest itself.

### External Runtime Dependency

The ADOT collector is not built by this repository's application image release. Its image must be selected through explicit dependency review and pinned by digest. A mutable `latest` or version-only tag is insufficient for deployment reproducibility.

The operator has resolved and validated the collector URI, but its exact digest was not supplied for this patch. Populate `ADOT_COLLECTOR_IMAGE_URI` in `development-plan` with the full `public.ecr.aws/aws-observability/aws-otel-collector@sha256:<64-hex>` URI. The explicit mapping supplies `TF_VAR_adot_collector_image_uri` to Terraform; no digest is fabricated here. Backend configuration is not the place for this value, and Apply continues using the verified binary plan.

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

9. Verify shared DNS deployment and Namecheap delegation, then resolve development configuration: exact FQDN, hosted-zone ID, recorded WAF pins and their delivery, operator-validated ADOT digest, worker target, and alarm thresholds.
10. Run an authenticated Terraform plan for `infrastructure/environments/development` with the selected release manifest and reviewed development configuration.
11. Review and approve the complete plan and its identity, backend key, input provenance, and expected changes.

**Hard gate E:** Missing, fabricated, mutable, or unreviewed inputs stop planning/approval. A successful plan is not authorization to bypass the ECS sequencing blocker.

12. Apply the development foundation with `ecs_services_enabled = false` so prerequisites and task definitions exist without API/worker services or autoscaling.
13. Run the one-off migration task using the approved task-definition revision.
14. Wait for the migration task to stop.
15. Verify that the migration container exited successfully and preserve its logs/task evidence.
16. If migration fails, **STOP THE RELEASE**. Do not update either API or worker service.

**Hard gate F:** A verified zero/success migration result is mandatory before service mutation. Timeout, task-launch failure, missing evidence, or non-zero exit is failure.

17. Only after migration success, review a separate change to the workflow's fixed bootstrap gate before creating initial services and autoscaling with `ecs_services_enabled = true`. Later releases update the approved API/worker task-definition revisions through release orchestration after migration success.
18. Wait for both ECS services to reach stability and verify expected task counts and target health.

**Hard gate G:** Unstable services, failed tasks, unhealthy targets, or unexpected revisions stop acceptance and trigger diagnosis/rollback according to the future release runbook.

19. Perform live synchronous and asynchronous verification.
20. Preserve the plan approval, release manifest, image digests, migration result, service rollout evidence, health checks, logs, queue evidence, report artifact, and durable job state.

**Hard gate H:** The deployment is accepted only when the complete acceptance contract below is evidenced. Terraform apply success by itself is insufficient.

There is no local `terraform apply` path. Deployment runs GitHub Actions -> GitHub OIDC -> AWS IAM -> Terraform/AWS.

## 7. ECS Bootstrap Gate And Release Boundary

The development input `ecs_services_enabled` defaults to `false` and flows to the ECS module's `services_enabled` input. Both API/worker service resources and the development autoscaling module have conditional counts, so they are absent during foundation bootstrap. The cluster, log groups, and API/worker/migration task definitions can be created without starting application services.

After a successful migration is evidenced, a separate reviewed change to the workflow's fixed bootstrap gate may permit a plan with `ecs_services_enabled = true` to create the initial services. Changing a GitHub Environment Variable cannot enable the gate. The flag does not invoke the migration or validate its exit code; the operator and release orchestration must enforce this sequence:

```text
register task definitions
  -> run migration
  -> wait
  -> verify successful exit
   -> enable initial services or update existing services
```

Service creation or updates must stop if migration evidence is missing or unsuccessful. Plan approval does not waive that gate.

The existing ownership boundary is:

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

The ECS services already ignore drift only for `task_definition` and `desired_count`: Terraform owns initial service creation and infrastructure, release orchestration owns later approved live revisions, and Application Auto Scaling owns runtime desired count. The bootstrap safety gate is implemented in source, but migration execution, release sequencing, and successful runtime evidence are not proven by this readiness patch.

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
- The implemented bootstrap safety gate, migration-before-service requirement, and existing Terraform/release ownership boundary are documented.
- The synchronous and asynchronous deployment acceptance evidence is defined, and Terraform success alone is explicitly insufficient.
- Every currently unresolved value remains visibly unresolved; no deployment value has been fabricated.

Closing this documentation stage does not authorize an AWS deployment. Input delivery is implemented in source; the operator must populate the documented `development-plan` variables and prepare the provider lockfile before the first authenticated development plan. Initial service creation and later service updates require successful migration evidence first; the current workflow fixes the bootstrap flag as false until a separate reviewed change permits service creation.
