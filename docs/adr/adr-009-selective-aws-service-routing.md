# ADR-009: Selective AWS-Service Routing: S3 Gateway Endpoint + Retained NAT

## Status

Accepted.

## Context

ECS/Fargate tasks run in private application subnets. The development VPC already has a NAT Gateway and application-private default routes for external HTTPS egress.

Workloads may require external SaaS APIs, third-party APIs, and AWS public service endpoints. The worker writes S3 artifacts under `reports/*`, and ECR image-layer downloads use the regional S3 starport layer bucket.

Paid PrivateLink interface endpoints introduce endpoint-hour and data-processing cost. Blanket PrivateLink adoption is not automatically justified before traffic volume, compliance requirements, and availability needs are measured.

## Decision

Keep the existing NAT Gateway and add a regional S3 Gateway VPC Endpoint associated only with application-private route tables.

Do not associate the endpoint with public or database-private route tables. Preserve ECR starport layer bucket access in the endpoint policy. Defer paid interface endpoints for SQS, ECR API, ECR DKR, Secrets Manager, CloudWatch Logs, AMP, and X-Ray.

## Alternatives

1. NAT only.
2. All relevant interface endpoints plus S3 Gateway Endpoint.
3. Remove NAT and use endpoint/private-only egress.
4. Selected hybrid model.

The selected hybrid model is chosen.

## Consequences

Positive:

- Same-Region S3 traffic no longer requires NAT.
- S3 Gateway Endpoint adds no endpoint hourly charge.
- Artifact traffic has direct AWS routing.
- ECR S3 layer access remains supported.
- External API access remains available.
- Operational complexity stays low.

Negative:

- NAT remains a cost and failure dependency.
- SQS, ECR API, ECR DKR, Secrets Manager, CloudWatch Logs, AMP, and X-Ray remain NAT-routed in development.
- The architecture is not fully private-service routed.
- Production may need endpoint reassessment.

## Review Triggers

- NAT processed-byte cost rises materially.
- Compliance requires private AWS API paths.
- Production removes general Internet access.
- NAT availability becomes unacceptable.
- CloudWatch or telemetry volume justifies endpoint economics.
- Security model requires `aws:sourceVpce` bucket enforcement.

