# Terraform Bootstrap

## What This Layer Creates

Bootstrap creates the AWS identity and Terraform state foundation:

- Terraform state S3 bucket
- GitHub Actions OIDC IAM identity provider
- temporary GitHub development deployment bridge role
- permanent GitHub development Terraform plan role
- permanent GitHub development Terraform apply role and least-privilege apply policies
- permanent GitHub development ECR publisher role
- permanent GitHub development ECS release role

It does not create ECR, ECS, VPC, RDS, ALB, SQS, application S3 buckets, Secrets Manager, deployment workflows, or application runtime infrastructure.

## Why Bootstrap Uses Local State First

Terraform cannot store state in an S3 backend before the S3 backend bucket exists. This bootstrap layer starts with local state, creates the state bucket, and then later environments can use that bucket as their remote backend.

Now that the bootstrap has already been applied and the bucket exists, the bootstrap state can be migrated into that same S3 backend.

The backend uses S3 native locking with `use_lockfile = true`. This stage intentionally does not create a DynamoDB locking table.

## Why Remote State Is Used

Remote state gives Terraform one shared source of truth instead of leaving important infrastructure state on one workstation. For this project, the S3 backend allows future CI and operators to read the same bootstrap state safely.

## Why Versioning Matters

The state bucket has versioning enabled so previous state object versions can be recovered if the current state is accidentally overwritten or corrupted. Current state is retained indefinitely. Noncurrent versions are retained for 90 days to provide a recovery window without keeping old versions forever.

## Why Locking Matters

Locking prevents two Terraform runs from modifying the same state at the same time. Without locking, concurrent runs can corrupt state or cause one operator's changes to overwrite another operator's view of infrastructure.

## Why S3 Native Locking Instead Of DynamoDB

This bootstrap uses S3 native locking through `use_lockfile = true` because it keeps the bootstrap layer small and avoids creating an extra DynamoDB table only for locks. DynamoDB locking is still common in older Terraform estates, but this project intentionally uses the simpler current S3 backend locking path.

## GitHub Development Identity Model

Bootstrap owns the GitHub OIDC provider and the permanent GitHub Actions role trust policies.

```text
development-plan
  -> pcrp-GitHubDevelopmentTerraformPlan

development-apply
  -> pcrp-GitHubDevelopmentTerraformApply

development-publish
  -> pcrp-GitHubDevelopmentEcrPublisher

development-release
  -> pcrp-GitHubDevelopmentEcsRelease
```

The older `ProductionCloudReliabilityPlatform-GitHubDevelopmentDeployment` role remains a temporary bridge only. It is not a normal deployment identity and should be retired after the permanent identities are provisioned and verified.

The bootstrap source declares the already-authoritative Plan identity as `pcrp-GitHubDevelopmentTerraformPlan`. Before any bootstrap apply, verify that the bootstrap state address already resolves to that AWS role. If state still records the older long-form Plan role name, stop and reconcile state/import ownership before accepting any role replacement.

Trust answers "who can become this role"; permissions answer "what can this role do after it is assumed." Each permanent role trusts only the bootstrap-owned GitHub Actions OIDC provider and only one exact GitHub environment subject.

## Why `aud` And Exact `sub` Are Checked

The `aud` claim must equal `sts.amazonaws.com`, proving the token was issued for AWS STS role assumption.

The permanent role `sub` claims must exactly match:

```text
development-plan:
repo:Chisom-Eze@215772129/Production-Cloud-Reliability-Platform@1340202037:environment:development-plan

development-apply:
repo:Chisom-Eze@215772129/Production-Cloud-Reliability-Platform@1340202037:environment:development-apply

development-publish:
repo:Chisom-Eze@215772129/Production-Cloud-Reliability-Platform@1340202037:environment:development-publish

development-release:
repo:Chisom-Eze@215772129/Production-Cloud-Reliability-Platform@1340202037:environment:development-release
```

The temporary bridge role still trusts only the exact legacy `development` subject. None of the GitHub trusts use wildcards or `StringLike`.

## Terraform Apply Boundary

`pcrp-GitHubDevelopmentTerraformApply` can read and write only the approved non-bootstrap Terraform states:

```text
shared/container-registry/terraform.tfstate
shared/security-audit/terraform.tfstate
environments/development/terraform.tfstate
```

It can acquire and release those states' `.tflock` objects. It cannot delete Terraform state objects, and it has an explicit deny on:

```text
bootstrap/terraform.tfstate
bootstrap/terraform.tfstate.tflock
```

Terraform Apply owns infrastructure mutation for the approved shared and development roots. It does not publish container images and cannot execute migration tasks. It can register task definitions because task-definition registration remains Terraform-owned.

Apply permissions are split into exactly eight bootstrap-owned customer-managed policies so each document stays reviewable and below IAM managed-policy size limits: Backend, Network, Edge, Data, Runtime, ObservabilityAudit, Iam, and DeploymentBoundaries. The Network/Edge and Data/Runtime responsibilities are separate policies because the former combined documents exceeded AWS IAM's 6144-character managed-policy limit.

`Resource = "*"` remains only where the AWS API or provider discovery operation has no usable resource-level authorization, including selected read/list/describe calls, `sqs:CreateQueue`, `ecs:RegisterTaskDefinition`, CloudWatch Logs query/log-delivery control-plane calls, and AMP/Grafana workspace creation. Explicit deny statements may also use `"*"` to enforce a boundary globally. Generated infrastructure is otherwise constrained to exact ARNs or account/Region resource-type ARN patterns; Route 53 remains limited to hosted-zone ARNs because the selected zone ID is a downstream development input.

Terraform Apply may manage only development/shared IAM resources intentionally owned by downstream roots. It cannot administer the GitHub OIDC provider or the GitHub deployment roles' trust policies. Its downstream exceptions are attaching the exact `ProductionCloudReliabilityPlatformEcrPublish` managed policy to `pcrp-GitHubDevelopmentEcrPublisher` and managing the exact development-owned `pcrp-GitHubDevelopmentEcsReleaseRuntime` managed policy.

The Release runtime policy ARN is deterministic: `arn:aws:iam::<account-id>:policy/pcrp-GitHubDevelopmentEcsReleaseRuntime`. Apply can create, version, read, tag, and delete only that managed policy. It can attach or detach only that policy on `pcrp-GitHubDevelopmentEcsRelease`; explicit denies block inline-policy mutation and any other managed-policy attachment on the Release role.

## Why Immutable Owner And Repository IDs Matter

GitHub repository and owner names can be renamed. Numeric owner and repository IDs are immutable, so including them in the OIDC subject reduces the risk that a renamed or recreated repository accidentally satisfies the trust policy.

## Why GitHub Needs No Static AWS Credentials

GitHub Actions receives a short-lived OIDC token during a workflow run. AWS STS validates that token against the IAM OIDC provider and role trust policy, then returns short-lived AWS credentials for that role.

No long-lived AWS access keys are stored in GitHub.

Backend credentials must also not be committed. Terraform should use the operator's local AWS profile, SSO session, environment, or later OIDC-based CI identity to access the backend.

## Usage

Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Replace `ACCOUNT_ID` in `state_bucket_name` with the real AWS account ID or another globally unique suffix.

Then run from this directory:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
```

Do not run `terraform apply` until you are ready to create the bootstrap resources.

## Remote State Migration

Create a local backend configuration file from the example:

```bash
cp backend.s3.tfbackend.example backend.s3.tfbackend
```

Edit `backend.s3.tfbackend` locally and replace `<STATE_BUCKET_NAME>` with the existing bootstrap state bucket name from:

```bash
terraform output -raw state_bucket_name
```

`backend.s3.tfbackend` is ignored by Git because it is machine/operator-specific backend configuration. The example file is safe to commit because it contains no credentials.

Then migrate the existing local bootstrap state into S3:

```bash
terraform init -migrate-state -backend-config=backend.s3.tfbackend
```

Use `-migrate-state` because it preserves Terraform state lineage while moving the existing state from local storage into the configured S3 backend. Do not use `-reconfigure` for the migration step: `-reconfigure` accepts the new backend configuration but does not migrate existing local state into it.

After migration, verify the backend and state:

```bash
terraform state list
terraform output state_bucket_name
terraform plan
```

Expected state resources include:

```text
aws_s3_bucket.terraform_state
aws_s3_bucket_public_access_block.terraform_state
aws_s3_bucket_versioning.terraform_state
aws_s3_bucket_server_side_encryption_configuration.terraform_state
aws_s3_bucket_ownership_controls.terraform_state
aws_s3_bucket_lifecycle_configuration.terraform_state
aws_s3_bucket_policy.terraform_state_tls_only
aws_iam_openid_connect_provider.github_actions
aws_iam_role.github_development_deployment
aws_iam_role.github_development_terraform_plan
aws_iam_role.github_development_terraform_apply
aws_iam_role.github_development_ecr_publisher
aws_iam_role.github_development_ecs_release
```

## Rollback And Recovery Notes

- Keep a backup copy of the local `terraform.tfstate` until the migration is verified.
- If migration fails before completing, stop and inspect the error before rerunning.
- Do not use `terraform state push` unless there is a deliberate recovery plan.
- Do not use `terraform force-unlock` unless a real stale lock is confirmed.
- S3 versioning provides recovery points for the remote state object after migration.
