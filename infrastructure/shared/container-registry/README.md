# Shared Container Registry

This root owns the shared ECR infrastructure used by later image publishing stages.

It creates the API, worker, and Nginx ECR repositories through `infrastructure/modules/ecr` and attaches narrowly scoped ECR publishing permissions to the permanent GitHub development ECR publisher role created by bootstrap.

This root does not create ECS services, task definitions, load balancers, databases, queues, application buckets, deployment workflows, or runtime infrastructure.

## Resources

- `production-cloud-reliability-api`
- `production-cloud-reliability-worker`
- `production-cloud-reliability-nginx`
- ECR lifecycle policies that expire only untagged images older than 7 days
- customer-managed `ProductionCloudReliabilityPlatformEcrPublish` policy attachment on `pcrp-GitHubDevelopmentEcrPublisher`

## Permission Boundary

`ecr:GetAuthorizationToken` requires `Resource = "*"`, because AWS does not scope that API to one repository ARN.

All repository actions are scoped to the three project ECR repository ARNs. GitHub can upload layers, publish image manifests, and inspect pushed images. It cannot create repositories, delete repositories, change repository policies, change lifecycle policies, or change image tag mutability.

The Publisher identity cannot read Terraform state, mutate ECS services, administer IAM, or change infrastructure. Terraform owns repository infrastructure; Publisher owns image publication only.

## State Boundary

This is a standalone Terraform root with its own backend block and state key:

```text
shared/container-registry/terraform.tfstate
```

It does not share state with bootstrap or any runtime environment root.
