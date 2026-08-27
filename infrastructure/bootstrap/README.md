# Terraform Bootstrap

## What This Layer Creates

Stage 2A creates only the AWS identity and Terraform bootstrap layer:

- Terraform state S3 bucket
- GitHub Actions OIDC IAM identity provider
- GitHub development deployment IAM role

It does not create ECR, ECS, VPC, RDS, ALB, SQS, application S3 buckets, Secrets Manager, or application infrastructure.

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

## Trust Policy Vs Permissions Policy

The deployment role has a trust policy that defines who may assume the role. In this stage, only one exact GitHub Actions OIDC subject is trusted.

The deployment role intentionally has no broad permissions policy yet. Trust answers "who can become this role"; permissions answer "what can this role do after it is assumed." Stage 2A proves federation before granting deployment power.

## Why `aud` And Exact `sub` Are Checked

The `aud` claim must equal `sts.amazonaws.com`, proving the token was issued for AWS STS role assumption.

The `sub` claim must exactly match:

```text
repo:Chisom-Eze@215772129/Production-Cloud-Reliability-Platform@1340202037:environment:development
```

That means only the intended repository identity and GitHub environment can assume this role.

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
```

## Rollback And Recovery Notes

- Keep a backup copy of the local `terraform.tfstate` until the migration is verified.
- If migration fails before completing, stop and inspect the error before rerunning.
- Do not use `terraform state push` unless there is a deliberate recovery plan.
- Do not use `terraform force-unlock` unless a real stale lock is confirmed.
- S3 versioning provides recovery points for the remote state object after migration.
