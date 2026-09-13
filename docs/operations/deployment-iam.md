# Deployment IAM

This document records the Stage D3 deployment IAM boundary for the Production Cloud Reliability Platform.

## Current Stage

Stage D3 introduces only authenticated Terraform plan authorization.

The target milestone is:

```text
GitHub Actions
  -> GitHub OIDC
  -> dedicated Terraform plan role
  -> remote S3 state with native S3 locking
  -> authenticated Terraform plan
```

This stage does not introduce Terraform apply permissions, ECS release permissions, ECR publishing changes, long-lived AWS keys, local Terraform apply, DynamoDB locking, or AdministratorAccess.

## Identity Separation

The existing proven OIDC role remains:

```text
ProductionCloudReliabilityPlatform-GitHubDevelopmentDeployment
```

That role is kept unchanged in Stage D3. It remains a temporary transition bridge for the one-time bootstrap IAM update after an explicitly privileged operator grants it narrowly scoped transition permissions.

The new permanent plan role is:

```text
pcrp-GitHubDevelopmentTerraformPlan
```

The plan role is read-only for AWS infrastructure inspection and has only the S3 backend permissions required to read approved non-bootstrap state and acquire/release native S3 lockfiles.

Apply, release, publisher, shared-apply, and permanent bootstrap-apply identities are intentionally deferred until authenticated plan behavior is proven.

## GitHub OIDC Trust

The plan role trusts the existing bootstrap-owned GitHub OIDC provider.

Trust requires both:

```text
aud = sts.amazonaws.com
sub = repo:Chisom-Eze@215772129/Production-Cloud-Reliability-Platform@1340202037:environment:development-plan
```

The trust uses the same immutable owner/repository ID subject format already used by bootstrap. It does not use wildcard repository trust, organization-wide trust, or mutable repository-name-only trust.

The future workflow that uses this role must run in the GitHub environment named:

```text
development-plan
```

## State Boundary

The plan role can read these non-bootstrap state objects:

```text
shared/container-registry/terraform.tfstate
shared/security-audit/terraform.tfstate
environments/development/terraform.tfstate
```

It can acquire and release native S3 lockfiles for those same states:

```text
shared/container-registry/terraform.tfstate.tflock
shared/security-audit/terraform.tfstate.tflock
environments/development/terraform.tfstate.tflock
```

The plan role cannot write or delete `.tfstate` objects.

The plan role is explicitly denied access to:

```text
bootstrap/terraform.tfstate
bootstrap/terraform.tfstate.tflock
```

Bootstrap state remains outside normal development plan authority because it owns the control-plane identities and Terraform state bucket.

## AWS Boundary

Terraform plan may inspect AWS configuration required for provider refresh, data sources, and planning across the non-bootstrap roots:

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

Stage D3 adds:

```text
.github/workflows/bootstrap-iam-transition.yml
```

This workflow is temporary. It exists only to apply the bootstrap IAM transition after an explicitly privileged operator temporarily grants the existing proven OIDC role the required bootstrap transition permissions.

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

After the plan role is provisioned and verified, remove this temporary workflow.

## Future Stages

Later work will introduce separate identities for:

* development Terraform apply
* shared infrastructure apply
* ECR publishing
* ECS migration and release orchestration

Those roles should be added only after authenticated plan succeeds and should preserve separation between state access, infrastructure mutation, image publishing, and ECS release operations.

