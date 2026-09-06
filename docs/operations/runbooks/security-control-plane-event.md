# Runbook: Security Control-Plane Event

## SYMPTOM

A targeted EventBridge security rule publishes to the dedicated security SNS topic.

## SECURITY IMPACT

The event may indicate root usage, IAM privilege change, network perimeter change, S3 security posture change, console login without MFA, or CloudTrail tampering.

## PRIMARY SIGNAL

Security SNS notification from an EventBridge rule backed by CloudTrail API activity.

## FIRST CHECKS

Identify `eventTime`, `eventSource`, `eventName`, `userIdentity`, `sourceIPAddress`, `awsRegion`, `requestID`, and affected resources.

## IDENTITY INVESTIGATION

Determine whether the principal is expected for the operation. Check whether the identity is root, a human user, an assumed role, a GitHub OIDC role, an AWS service role, or an unknown session.

## SOURCE-IP / SESSION INVESTIGATION

Review source IP, user agent, role session name, MFA context where available, and whether the timing matches an approved change.

## CLOUDTRAIL CORRELATION

Use CloudTrail Event History and the delivered S3 audit trail to reconstruct the action sequence around the event.

## EXPECTED CHANGE CORRELATION

Compare the event with Terraform changes, GitHub Actions runs, deployment activity, incident timelines, and approved maintenance windows.

## LIKELY CAUSES

Approved infrastructure change, emergency administrative action, misconfigured automation, unexpected human console/API usage, compromised credentials, or attempted audit/security tampering.

## SAFE CONTAINMENT OPTIONS

Containment depends on evidence. Options may include pausing the related deployment, restricting an affected principal through an approved change, rotating credentials through the normal process, or escalating to the account owner/security contact.

Do not blindly delete identities, revoke every policy, destroy resources, or purge logs.

## RECOVERY / CLOSURE CRITERIA

The change is confirmed authorized or contained, affected resources are reviewed, monitoring is stable, and evidence is preserved.

## ESCALATION

Escalate root activity, CloudTrail tampering, unknown privilege changes, or suspicious source locations immediately.

## EVIDENCE PRESERVATION

Preserve the notification, CloudTrail event details, related S3 audit objects, request IDs, Terraform/GitHub references, and operator notes.

