# RDS Module

This module creates the PostgreSQL RDS foundation for an environment.

## Owned Resources

- RDS DB subnet group.
- PostgreSQL RDS instance.
- CloudWatch log groups for exported PostgreSQL logs.
- Optional Enhanced Monitoring IAM role and AWS managed policy attachment.

## Security Model

The instance is private-only:

- `publicly_accessible = false`
- caller-provided private database subnets
- caller-provided RDS security group IDs
- RDS-managed master password
- encrypted gp3 storage using the default AWS-managed RDS key

This module does not create security-group rules. Network trust stays in the environment security-group layer.

## Credentials

The module uses `manage_master_user_password = true`. Terraform does not accept, store, or output a plaintext database password. RDS creates and rotates the master user secret through the managed password feature.

The secret ARN is exposed as a sensitive output so later application stages can wire secret access deliberately.

## Backups And Deletion

Automated backups, backup windows, deletion protection, and final snapshot behavior are inputs. Environment roots must set these explicitly so development, staging, and production trade-offs are visible in code.

## Observability

PostgreSQL and upgrade logs can be exported to CloudWatch Logs with configurable retention. Enhanced Monitoring is enabled when `enhanced_monitoring_interval` is greater than zero.

Performance Insights is exposed as an input for supported instance classes. No customer-managed KMS key is configured in this stage.
