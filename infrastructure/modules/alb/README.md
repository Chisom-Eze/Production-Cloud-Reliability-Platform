# ALB Module

This module creates the public application edge load balancer and its dedicated access-log bucket.

## Owned Resources

- Internet-facing Application Load Balancer.
- API target group for future ECS/Fargate IP targets.
- HTTP listener that redirects to HTTPS.
- HTTPS listener that forwards to the API target group.
- Dedicated private S3 bucket for ALB access logs.
- ALB access-log bucket policy and lifecycle controls.

## Edge Model

The ALB is placed in public subnets and uses only the caller-provided ALB security group. It forwards to the future API ECS service target group on HTTP port 80. FastAPI port 8000 and PostgreSQL port 5432 are not exposed by the ALB.

HTTP port 80 redirects to HTTPS port 443. HTTPS terminates at the ALB using the validated ACM certificate ARN passed by the environment root.

## Health Checks

The target group uses `/health`. This checks that the Nginx/FastAPI task can respond without converting a downstream dependency outage into load-balancer-driven task replacement churn. Readiness checks such as `/ready` can be used later by ECS deployment controls when deliberately designed.

## Access Logs

The module creates a dedicated private S3 bucket for ALB access logs. The bucket uses full Public Access Block, `BucketOwnerEnforced` ownership, SSE-S3 with `AES256`, versioning, finite retention, and a TLS-only deny policy.

ALB log delivery uses the current service principal `logdelivery.elasticloadbalancing.amazonaws.com`, scoped to the account-specific `AWSLogs/<account-id>/` prefix.
