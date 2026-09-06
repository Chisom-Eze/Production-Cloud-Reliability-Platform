# Runbook: CloudTrail Integrity

## SYMPTOM

EventBridge reports CloudTrail tampering, such as `StopLogging`, `DeleteTrail`, `UpdateTrail`, `PutEventSelectors`, or `PutInsightSelectors`.

## SECURITY IMPACT

CloudTrail tampering is critical because it can reduce or destroy the account's ability to reconstruct AWS control-plane activity.

## PRIMARY SIGNAL

The CloudTrail tampering EventBridge rule and security SNS notification.

## FIRST CHECKS

Identify the actor, source IP, region, request ID, event name, and affected trail. Determine whether the event aligns with an approved change.

## TRAIL STOPPED

If logging was stopped, determine when it stopped, who stopped it, whether events are still visible in CloudTrail Event History, and whether the delivered S3 trail contains events up to the stop time.

## TRAIL DELETED

If the trail was deleted, preserve available evidence from Event History, S3 delivered logs, Terraform history, and related account activity.

## EVENT SELECTORS MODIFIED

If event selectors changed, confirm whether management events still include read and write activity and whether data events were intentionally changed.

## LOGGING DESTINATION ALTERED

If the S3 destination or prefix changed, verify whether delivery still targets the dedicated audit bucket and expected account prefix.

## LOG FILE VALIDATION

Stage L enables CloudTrail log file validation. CloudTrail publishes digest information that can later help verify whether delivered log files were modified or deleted after delivery.

This does not prevent deletion and digest validation is not continuously executed by this project today. Runtime validation must be performed after deployment.

## SAFE CONTAINMENT OPTIONS

Containment is contextual. Preserve evidence first, confirm authorization, and restore the intended trail configuration through the approved infrastructure process.

Do not purge logs or manually delete audit evidence.

## RECOVERY / CLOSURE CRITERIA

The intended trail is logging, management read/write events are enabled, multi-Region and global service event settings are intact, log file validation is enabled, S3 delivery is healthy, and the incident timeline is documented.

## ESCALATION

Escalate immediately to the account owner/security contact if the change was not approved or the actor cannot be explained.

