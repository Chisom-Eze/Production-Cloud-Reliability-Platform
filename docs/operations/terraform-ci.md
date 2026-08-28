# Terraform CI Static Quality Gates

## Architecture And CI Decision

This stage adds a static Terraform quality gate before any authenticated plan or apply workflow exists.

The pipeline is intentionally narrow:

```text
Terraform change
  -> terraform fmt
  -> terraform init -backend=false
  -> terraform validate
  -> TFLint
  -> Trivy IaC scan
  -> PASS / BLOCK
```

It does not authenticate to AWS, run `terraform plan`, run `terraform apply`, publish Docker images, or deploy ECS.

## Terraform Roots

Current real Terraform roots:

- `infrastructure/bootstrap`

No reusable module directory currently contains Terraform files. A directory is not treated as a Terraform root unless it has root-module configuration that must be initialized and validated independently.

## Terraform fmt

`terraform fmt -check -recursive infrastructure` checks whether committed Terraform files use Terraform's canonical formatting.

CI checks formatting instead of automatically rewriting source code because CI should report whether the proposed source is acceptable. Rewriting in CI would create a difference between the reviewed commit and the tested code, and it would hide formatting feedback from the developer.

## Terraform validate

`terraform validate` checks whether a Terraform root is internally valid after providers are initialized. It catches malformed resource blocks, unsupported arguments, invalid references, and type errors that Terraform can detect statically.

`terraform fmt` checks layout. `terraform validate` checks Terraform configuration validity.

## Static Initialization

CI uses:

```bash
terraform init -backend=false
```

That installs providers for validation but does not connect to or mutate the configured S3 backend. If `.terraform.lock.hcl` already exists in a root, CI uses lockfile read-only behavior so provider selections are not silently changed.

`.terraform.lock.hcl` should remain committed once generated. It records provider selections and helps CI and developers use the same provider versions.

## TFLint

TFLint detects Terraform quality and provider-specific issues that `terraform validate` may not catch, such as invalid AWS instance types, deprecated arguments, missing recommended constraints, or provider-specific best-practice violations.

This repository enables the AWS ruleset because the current Terraform targets AWS.

## Trivy IaC Scan

Trivy scans `infrastructure/` for infrastructure-as-code security and misconfiguration findings.

The initial blocking policy fails on:

- HIGH
- CRITICAL

LOW and MEDIUM findings remain visible without initially blocking the build.

Examples of issues Trivy can detect that Terraform may consider valid include public S3 access, missing encryption, overly permissive security groups, missing logging, or weak resource policies.

Suppressions should not be added globally. Any future suppression should include a documented reason.

## Why This Workflow Does Not Run Terraform Plan

`terraform plan` usually needs backend access, provider credentials, remote state, and real AWS API reads. This stage is deliberately unauthenticated and static.

The authenticated Terraform plan workflow will be a separate stage with its own IAM, OIDC, remote-state, and environment controls.

## Workflow Triggers

The workflow runs on pull requests targeting `main` when relevant files change:

- `infrastructure/**`
- `.tflint.hcl`
- `.github/workflows/terraform-ci.yml`
- `scripts/terraform-quality.sh`
- `docs/operations/terraform-ci.md`

It also supports `workflow_dispatch` for manual validation.

## Concurrency

Pull request CI uses concurrency so a newer commit to the same PR cancels an obsolete Terraform static-check run.

That is appropriate for static checks because no infrastructure is being changed. The same behavior should not be copied into future Terraform apply workflows without reviewing deployment concurrency, locking, environment protection, and rollback behavior.

## Local Verification

Use WSL or another Linux shell with Terraform, TFLint, and Trivy installed:

```bash
cd /mnt/c/Users/AGU/Documents/Codex/2026-08-20/re
bash scripts/terraform-quality.sh
```

Equivalent manual commands:

```bash
terraform fmt -check -recursive infrastructure
terraform -chdir=infrastructure/bootstrap init -backend=false
terraform -chdir=infrastructure/bootstrap validate
tflint --init
tflint --config "$PWD/.tflint.hcl" --chdir=infrastructure/bootstrap
trivy config --severity LOW,MEDIUM --exit-code 0 infrastructure
trivy config --severity HIGH,CRITICAL --exit-code 1 infrastructure
```

Expected result:

- Formatting check passes.
- Static initialization does not contact the S3 backend.
- Terraform validation passes.
- TFLint reports no blocking errors.
- Trivy blocks only HIGH or CRITICAL infrastructure misconfiguration findings.
