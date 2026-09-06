# ACM DNS Module

This module creates and validates one public ACM certificate through Route 53 DNS validation.

## Owned Resources

- Public ACM certificate for the exact application FQDN.
- Route 53 DNS validation records in an existing hosted zone.
- ACM certificate validation resource.

## Ownership Boundary

The module does not create or own the Route 53 hosted zone. The environment root must pass the intended hosted-zone ID explicitly.

The module also does not create the application ALB alias record. The environment root owns that record because it needs both ACM/DNS and ALB outputs.

## Certificate Lifecycle

The certificate uses `create_before_destroy` so replacement can happen safely without intentionally removing the existing certificate first.
