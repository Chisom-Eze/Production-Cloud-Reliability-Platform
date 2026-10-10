# WAF Module

This module creates a REGIONAL AWS WAFv2 Web ACL for an Application Load Balancer.

## Owned Resources

- WAFv2 Web ACL.
- Four AWS managed rule groups.
- IP-based rate-limit rule.
- Web ACL association to the supplied ALB ARN.
- Dedicated CloudWatch Logs log group.
- WAF logging configuration with selected header redaction.

## Security Baseline

The Web ACL default action is allow. Explicit managed rules and the rate-limit rule block matching traffic.

Managed rule groups use `override_action = none`, so AWS managed rule actions are enforced rather than counted globally.

The baseline includes:

- `AWSManagedRulesCommonRuleSet`
- `AWSManagedRulesKnownBadInputsRuleSet`
- `AWSManagedRulesSQLiRuleSet`
- `AWSManagedRulesAmazonIpReputationList`

Bot Control, Fraud Control, ATP, CAPTCHA, Challenge, and blanket Anonymous IP blocking are intentionally omitted until there is a business and cost justification.

## Managed Rule Versions

`AWSManagedRulesCommonRuleSet`, `AWSManagedRulesKnownBadInputsRuleSet`, and `AWSManagedRulesSQLiRuleSet` require explicit static version inputs: `common_rule_set_version`, `known_bad_inputs_rule_set_version`, and `sqli_rule_set_version`.

`AWSManagedRulesAmazonIpReputationList` is intentionally unversioned. Its statement contains only the AWS vendor and rule-group name; the module has no version input for it. Its priority, enforcement, metrics, and sampled requests follow the existing baseline.

Use reviewed versions discovered from AWS for the target deployment. The recommended current default may not be the numerically highest available version. Revisit static pins before expiration and apply any version change through review.

## Logging And Privacy

WAF logs are written to a dedicated CloudWatch Logs group whose name starts with `aws-waf-logs-`.

Authorization and Cookie headers are redacted. Applications must still avoid putting secrets in URLs because URI and query metadata can remain operationally useful in logs.

CloudWatch Logs uses service-managed encryption at rest in this stage. No customer-managed KMS key is created.
