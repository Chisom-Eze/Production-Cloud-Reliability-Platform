# Production Environment

This future Terraform root will own production runtime infrastructure with its own remote state key:

```text
environments/production/terraform.tfstate
```

Production should use stronger availability, retention, deletion protection, alerting, promotion, rollback, and change-management controls where justified. Runtime resources are intentionally not implemented in this structure stage.
