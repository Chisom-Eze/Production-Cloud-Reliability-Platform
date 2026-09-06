# VPC Endpoints Module

This module currently creates only one regional Amazon S3 Gateway VPC Endpoint.

## Scope

The endpoint is associated only with application-private route tables. It is not associated with public route tables or database-private route tables.

The module does not create interface endpoints, endpoint ENIs, endpoint security groups, subnet associations, NAT gateways, route tables, IAM roles, IAM policies, KMS keys, S3 buckets, or observability resources.

## Routing

Gateway endpoint association lets AWS install the managed S3 prefix-list route in the selected route tables. The module does not create a separate `aws_route` for S3 and does not create `aws_vpc_endpoint_route_table_association` resources.

The application-private `0.0.0.0/0` route to NAT remains outside this module and is intentionally retained by the VPC module.

## Endpoint Policy

The endpoint policy is a network-path authorization layer. It does not replace workload IAM. Both the endpoint policy and the workload identity policy must allow an operation.

The policy permits:

- `s3:GetObject` and `s3:PutObject` on the application artifact report path `reports/*`
- `s3:GetObject` on the regional ECR starport layer bucket path

The policy does not grant `s3:DeleteObject`, `s3:*`, or bucket listing.

`Principal = "*"` is used because the endpoint policy is scoped by narrow actions/resources and does not independently grant identity permissions.

