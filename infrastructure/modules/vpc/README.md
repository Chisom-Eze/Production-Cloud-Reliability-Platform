# VPC Module

This module creates one VPC network foundation for a runtime environment.

It manages the VPC, Internet Gateway, public subnets, application-private subnets, database-private subnets, route tables, NAT Gateways, Elastic IPs required by NAT, and route-table associations.

The module does not create ALB, ECS, RDS, security groups, VPC endpoints, SQS, S3, Secrets Manager, CloudWatch, Route53, WAF, or KMS resources.

## NAT Strategy

`nat_gateway_strategy` controls application-private subnet egress:

- `single`: one NAT Gateway in the first configured AZ.
- `per_az`: one NAT Gateway per configured AZ.
- `none`: no NAT Gateway and no default route from application-private subnets.

Environment roots choose the strategy. The module does not contain production-specific conditionals.
