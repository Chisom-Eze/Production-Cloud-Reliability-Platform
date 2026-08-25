# Terraform Bootstrap

## What This Layer Creates

Stage 2A creates only the AWS identity and Terraform bootstrap layer:

- Terraform state S3 bucket
- GitHub Actions OIDC IAM identity provider
- GitHub development deployment IAM role

It does not create ECR, ECS, VPC, RDS, ALB, SQS, application S3 buckets, Secrets Manager, or application infrastructure.

## Why Bootstrap Uses Local State First

Terraform cannot store state in an S3 backend before the S3 backend bucket exists. This bootstrap layer starts with local state, creates the state bucket, and then later environments can use that bucket as their remote backend.

The future backend should be prepared to use S3 native locking with `use_lockfile = true`. This stage intentionally does not create a DynamoDB locking table.

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

