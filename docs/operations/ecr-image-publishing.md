# ECR Image Publishing Foundation

## Purpose

Stage 3A prepares the repository for a later image publishing workflow. It creates ECR repositories and grants the existing GitHub OIDC role only the permissions needed to push immutable API, worker, and Nginx images.

This stage does not deploy ECS, create task definitions, publish images, or promote releases.

## Repository Model

The platform uses three ECR repositories:

- `production-cloud-reliability-api`
- `production-cloud-reliability-worker`
- `production-cloud-reliability-nginx`

Each deployable component has its own repository instead of sharing one repository with service tags. This keeps repository ARNs, IAM permissions, scan evidence, and lifecycle behavior clear per component.

## Images, Repositories, Tags, And Digests

An image is a packaged filesystem and metadata bundle that can run as a container. An ECR repository is the registry location that stores related images. A tag is a human-readable pointer such as a Git commit SHA. A digest is the content-addressed identity of the exact image bytes.

The later publishing workflow will tag images with the Git commit SHA because it is readable and maps directly to source. The digest will become the authoritative deployment identity because it cannot drift if a tag name is reused elsewhere.

The project does not use `latest` as deployment identity. `latest` is mutable, ambiguous, and weak for incident response because it does not prove what code or image content was deployed.

## Immutability And Rollback

ECR image tags are immutable. Once `production-cloud-reliability-api:<git-sha>` exists, it cannot be overwritten with different image content.

The intended release model is:

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

The same digest should be promoted across environments. A rollback later means redeploying the previous known-good digest. For example, if production currently runs digest A and a release deploys digest B, rollback means redeploying digest A.

## GitHub OIDC Authorization

GitHub Actions will use OIDC to assume the existing development deployment role. No long-lived AWS access keys are stored in GitHub.

The role trust policy remains scoped to the existing repository and GitHub `development` environment subject. Stage 3A does not broaden the OIDC trust relationship.

`ecr:GetAuthorizationToken` requires `Resource = "*"`, because AWS does not scope that API to one repository ARN. The repository operations are scoped to only the three project ECR repository ARNs.

The role can authenticate, upload layers, publish manifests, and inspect pushed images. It cannot create repositories, delete repositories, change repository policies, change lifecycle policies, or alter image tag mutability. Terraform owns ECR infrastructure configuration.

## Scanning And Lifecycle

Trivy remains the CI enforcement mechanism for image vulnerabilities. The Terraform root does not configure registry-level ECR scanning in this stage because doing so affects registry-wide behavior and should be treated as a separate architectural decision.

Each repository has a lifecycle policy that expires untagged images older than 7 days. Tagged Git-SHA artifacts are not expired yet because deployment history, rollback windows, and promotion rules have not been implemented.
