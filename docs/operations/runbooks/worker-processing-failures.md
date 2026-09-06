# Runbook: Worker Processing Failures

## SYMPTOM

Worker logs show processing failures or `worker_jobs_processed_total{result="failure"}` increases.

## CUSTOMER/BUSINESS IMPACT

Reports may not be generated, jobs may retry, and repeated failures can eventually move messages to the DLQ.

## PRIMARY SIGNAL

`${project}-${environment}/worker/failures` and `worker_jobs_processed_total`.

## SUPPORTING SIGNALS

`worker_job_processing_duration_seconds`, `worker_job_claims_total`, `worker_duplicate_jobs_total`, `worker_outbox_dispatch_total`, `worker_outbox_reclaims_total`, `worker_visibility_heartbeat_failures_total`, SQS metrics, RDS metrics, and S3 evidence.

## FIRST CHECKS

Determine whether failures occur during outbox dispatch, SQS consume, job processing, artifact write, or durable database completion.

## CORRELATION PATH

Use `job_id` and `correlation_id` in worker logs. Use trace lookup when worker spans were sampled.

## LIKELY CAUSES

Invalid payload, database write/read failure, S3 write failure, SQS API failure, lost processing claim, stale lease, or bad worker deployment.

## SAFE MITIGATION OPTIONS

Let SQS retry and fencing handle transient failures, restore a known-good worker revision, scale capacity when saturation is confirmed, or remediate the failing dependency.

## RECOVERY CRITERIA

Worker failures stop, successful processing resumes, duplicate handling remains bounded, queue age recovers, and no new DLQ messages appear.

## ESCALATION / FOLLOW-UP

Document failed stage, sample job IDs, dependency behavior, retry outcome, and whether job processing needs stronger validation.

