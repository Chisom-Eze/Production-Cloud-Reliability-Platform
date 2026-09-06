# Security Groups Module

This module creates the application security-group trust graph for one runtime environment.

It creates four security groups:

- ALB
- API ECS tasks
- Worker ECS tasks
- RDS PostgreSQL

The module is intentionally cohesive because the rules express relationships between these identities. It does not create ALB, ECS, RDS, SQS, S3, Secrets Manager, CloudWatch, ACM, WAF, VPC endpoints, or KMS resources.

## Trust Graph

```text
Internet
  -> ALB security group TCP 80 and TCP 443
  -> API security group TCP 80

API security group
  -> RDS security group TCP 5432

Worker security group
  -> RDS security group TCP 5432
```

The worker has no inbound application rule. RDS trusts API and worker security group identities rather than VPC or subnet CIDR ranges.

API and worker egress allows TCP 443 to IPv4 destinations for HTTPS-based AWS APIs and permitted external dependencies through NAT. API and worker also have explicit TCP 5432 egress to the RDS security group.

There is no all-port, all-protocol workload egress rule.
