# Deployment IAM

This document records the deployment IAM boundary for the Production Cloud Reliability Platform.

## Current Stage

The permanent development IAM model now separates Terraform planning, Terraform apply, ECR publication, and ECS release orchestration into distinct GitHub OIDC roles.

The target milestone is:

```text
GitHub Actions
  -> GitHub OIDC
  -> pcrp-GitHubDevelopmentTerraformPlan
  -> remote S3 state with native S3 locking
  -> exact binary Terraform plan artifact
  -> human review
  -> pcrp-GitHubDevelopmentTerraformApply
  -> apply the exact reviewed plan
```

No role uses long-lived AWS keys, DynamoDB locking, AdministratorAccess, PowerUserAccess, or IAMFullAccess. Workflow implementation for publish and release remains separate work.

The bootstrap IAM transition has been completed by the operator, and the temporary AWS-side transition policy has been removed. The temporary repository workflow remains in place only for a later cleanup change and must not be used for normal operations.

## Identity Separation

The retired bootstrap bridge role is:

```text
ProductionCloudReliabilityPlatform-GitHubDevelopmentDeployment
```

That role must not be used for normal Terraform planning, application deployment, ECR publishing, or ECS release operations.

The active permanent plan role is:

```text
pcrp-GitHubDevelopmentTerraformPlan
```

The plan role is read-only for AWS infrastructure inspection and has only the S3 backend permissions required to read the approved non-bootstrap state and acquire/release native S3 lockfiles.

The permanent development identities are:

```text
development-plan    -> pcrp-GitHubDevelopmentTerraformPlan
development-apply   -> pcrp-GitHubDevelopmentTerraformApply
development-publish -> pcrp-GitHubDevelopmentEcrPublisher
development-release -> pcrp-GitHubDevelopmentEcsRelease
```

The temporary bridge remains present only until these permanent identities are provisioned and verified. Terraform Apply cannot access bootstrap state, publish images, or run migration tasks. Publisher cannot deploy ECS. Release cannot register task definitions or mutate infrastructure outside its exact runtime scope.

Terraform Apply receives exactly eight bootstrap-owned managed policies: `pcrp-GitHubDevelopmentTerraformApplyBackend`, `pcrp-GitHubDevelopmentTerraformApplyNetwork`, `pcrp-GitHubDevelopmentTerraformApplyEdge`, `pcrp-GitHubDevelopmentTerraformApplyData`, `pcrp-GitHubDevelopmentTerraformApplyRuntime`, `pcrp-GitHubDevelopmentTerraformApplyObservabilityAudit`, `pcrp-GitHubDevelopmentTerraformApplyIam`, and `pcrp-GitHubDevelopmentTerraformApplyDeploymentBoundaries`. Network and Edge, and Data and Runtime, remain separate to keep each generated policy document within the AWS IAM managed-policy size limit.

## Release Runtime Policy Boundary

The development root owns the customer-managed policy `pcrp-GitHubDevelopmentEcsReleaseRuntime` and attaches it only to `pcrp-GitHubDevelopmentEcsRelease`. Bootstrap continues to own the Release role and its exact `development-release` OIDC trust.

Terraform Apply can create, version, read, tag, and delete only `arn:aws:iam::<account-id>:policy/pcrp-GitHubDevelopmentEcsReleaseRuntime`. It can attach or detach only that policy on the Release role. Explicit denies prevent Release-role trust changes, deletion, permissions-boundary changes, inline-policy mutation, and attachment of any other managed policy.

The managed policy contains the existing Model B runtime permissions: migration-task execution and evidence collection, exact API/worker service promotion, exact workload-role pass-through to `ecs-tasks.amazonaws.com`, and explicit denial of Terraform-owned task-definition registration and deregistration.

## GitHub OIDC Trust

The Plan and Apply roles trust the existing bootstrap-owned GitHub OIDC provider through separate GitHub environments.

Each role trust checks `aud` and its exact environment-specific `sub`:

```text
aud = sts.amazonaws.com
sub = repo:Chisom-Eze@215772129/Production-Cloud-Reliability-Platform@1340202037:environment:development-plan

aud = sts.amazonaws.com
sub = repo:Chisom-Eze@215772129/Production-Cloud-Reliability-Platform@1340202037:environment:development-apply
```

The trust uses the same immutable owner/repository ID subject format already used by bootstrap. It does not use wildcard repository trust, organization-wide trust, or mutable repository-name-only trust.

The permanent workflows use these GitHub environments:

```text
Terraform Development Plan  -> development-plan
Terraform Development Apply -> development-apply
```

## State Boundary

The permanent development Plan and Apply workflows currently support only these shared Terraform roots:

```text
infrastructure/shared/container-registry
  -> shared/container-registry/terraform.tfstate

infrastructure/shared/security-audit
  -> shared/security-audit/terraform.tfstate
```

Both workflows map the selected logical root through an explicit allowlist. They do not accept arbitrary filesystem paths or backend keys. Each selected root initializes the S3 backend with:

```text
bucket       = pcrp-terraform-state-us-east-1
region       = us-east-1
encrypt      = true
use_lockfile = true
```

The corresponding native S3 lockfiles are:

```text
shared/container-registry/terraform.tfstate.tflock
shared/security-audit/terraform.tfstate.tflock
```

The plan role cannot write or delete `.tfstate` objects.

The plan role is explicitly denied access to:

```text
bootstrap/terraform.tfstate
bootstrap/terraform.tfstate.tflock
```

Bootstrap state remains outside normal development plan authority because it owns the control-plane identities and Terraform state bucket.

## AWS Boundary

Terraform plan may inspect AWS configuration required for provider refresh, data sources, and planning. The permanent workflow currently exercises only the shared container-registry and security-audit roots.

The plan identity has no apply, destroy, release, or publisher authority.

Read categories represented in the plan IAM design include:

* EC2/VPC networking
* Elastic Load Balancing v2
* ACM
* Route 53
* RDS
* SQS
* project S3 bucket configuration
* project IAM metadata
* ECS
* Application Auto Scaling
* CloudWatch
* CloudWatch Logs
* WAFv2
* ECR metadata
* CloudTrail
* EventBridge
* SNS
* Amazon Managed Service for Prometheus
* Amazon Managed Grafana
* Secrets Manager metadata

The plan role does not receive AWS managed `ReadOnlyAccess`. It uses a project-specific policy with explicit read/list/describe/get actions.

Secrets Manager access is metadata-only. The plan role does not receive `secretsmanager:GetSecretValue`.

## Explicit Exclusions

The plan role does not receive:

* `iam:PassRole`
* IAM create, update, delete, or policy-attachment permissions
* GitHub OIDC provider mutation
* ECR image-publishing actions
* ECR repository mutation actions
* ECS release mutation actions
* infrastructure create, update, or delete authority
* `.tfstate` write or delete authority
* bootstrap state access

Explicit deny statements protect the highest-risk boundaries: bootstrap state access, `.tfstate` mutation, IAM mutation/pass-role, ECR publishing/repository mutation, and ECS release mutation.

## Temporary Bootstrap Transition Workflow

The temporary bootstrap transition workflow remains in the repository during D4:

```text
.github/workflows/bootstrap-iam-transition.yml
```

This workflow is temporary. The operator has completed the bootstrap transition and removed the temporary AWS-side transition policy. Do not use this workflow for normal operations.

The workflow:

* runs only through `workflow_dispatch`
* has no push trigger
* has no pull request trigger
* uses `contents: read` and `id-token: write`
* uses the existing `development` GitHub environment
* assumes the existing proven deployment role
* operates only in `infrastructure/bootstrap`
* initializes the existing S3 backend with `use_lockfile = true`
* runs a fresh Terraform plan for both plan and apply modes
* applies only the exact saved plan file
* requires confirmation value `APPLY-BOOTSTRAP-IAM` before apply

After the permanent Plan and Apply workflows succeed end-to-end and evidence is captured, remove this temporary workflow in a separate cleanup change.

## Permanent Development Plan Workflow

Stage D4 adds:

```text
.github/workflows/terraform-plan-development.yml
```

The Plan workflow:

* runs only through `workflow_dispatch`
* has no push trigger
* has no pull request trigger
* uses `contents: read` and `id-token: write`
* uses the `development-plan` GitHub environment
* reads the role ARN from `vars.AWS_DEVELOPMENT_TERRAFORM_PLAN_ROLE_ARN`
* assumes `pcrp-GitHubDevelopmentTerraformPlan` through GitHub OIDC
* accepts only `shared/container-registry` or `shared/security-audit`
* maps the selected root to its exact filesystem path, backend key, and artifact slug
* initializes the S3 backend explicitly and does not depend on local `backend.s3.tfbackend`
* runs `terraform fmt -check`
* runs `terraform validate`
* runs `terraform plan -detailed-exitcode -out=tfplan`
* treats exit code `0` as no changes
* treats exit code `2` as successful changes detected
* treats exit code `1` as failure
* records repository, run, source, root, backend, region, Terraform version, result, and SHA-256 metadata
* uploads `tfplan` and `plan-metadata.json` as `terraform-plan-<run-id>-<root-slug>` for seven days

The Plan workflow does not run `terraform apply` or `terraform destroy`.

## Permanent Development Apply Workflow

The separately dispatched `.github/workflows/terraform-apply-development.yml` workflow:

* requires the exact confirmation `APPLY-DEVELOPMENT-TERRAFORM`
* uses `contents: read`, `actions: read`, and `id-token: write`
* uses the `development-apply` GitHub environment
* reads the role ARN from `vars.AWS_DEVELOPMENT_TERRAFORM_APPLY_ROLE_ARN`
* validates that `plan_run_id` identifies a successful `workflow_dispatch` run of `terraform-plan-development.yml` from `main` in the same repository
* checks out the exact Plan run head SHA rather than moving `main`
* downloads only the deterministic artifact for that Plan run and selected root
* validates the artifact metadata, allowlisted path and backend key, repository, run ID, source SHA, checked-out SHA, region, Terraform version, plan result, and plan SHA-256
* assumes `pcrp-GitHubDevelopmentTerraformApply` only after those checks succeed
* initializes the verified backend and applies only the downloaded binary plan
* never generates a replacement plan

Bootstrap and `infrastructure/environments/development` are not selectable. The development environment root remains blocked until its required deployment inputs and immutable release artifacts are resolved.

Successful execution of either permanent workflow is not claimed until the operator provides GitHub Actions evidence.

## Remaining Work

The permanent Apply, Publisher, and Release roles and their downstream-owned permissions are represented in Terraform source. The Plan and Apply workflow control plane is now represented for the two shared roots, but is not claimed runtime-verified by this change. Separate work must implement image-publication and release workflows, resolve development deployment inputs and immutable release artifacts, prove each OIDC environment binding, capture AccessDenied evidence for any missing operation, and retire the temporary bridge only after the permanent paths succeed.
