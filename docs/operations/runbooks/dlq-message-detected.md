# Runbook: DLQ Message Detected

## SYMPTOM

DLQ `ApproximateNumberOfMessagesVisible` is greater than zero.

## CUSTOMER/BUSINESS IMPACT

At least one job message exhausted normal retries and may require investigation before completion.

## PRIMARY SIGNAL

`${project}-${environment}-dlq-visible-messages-critical`.

## SUPPORTING SIGNALS

Worker failure logs, `worker_jobs_processed_total{result="failure"}`, `worker_outbox_dispatch_total{result="failure"}`, queue receive counts, job database state, and related `correlation_id`/`job_id` logs.

## FIRST CHECKS

Identify when the DLQ count increased, inspect worker failures around that window, and determine whether the error is deterministic, transient, duplicate-safe, or data-specific.

## CORRELATION PATH

Use `${project}-${environment}/worker/failures`, then job context in logs and database state. Use traces when worker spans exist.

## LIKELY CAUSES

Repeated processing exception, invalid job payload, S3 artifact write failure, database failure, SQS visibility/heartbeat issue, or bad worker revision.

## SAFE MITIGATION OPTIONS

Fix the root cause first. Replay or redrive only after confirming idempotency and data safety. Do not purge the queue as a recovery shortcut.

## RECOVERY CRITERIA

DLQ growth stops, root cause is understood, affected job disposition is documented, and normal queue processing is stable.

## ESCALATION / FOLLOW-UP

Record message timing, job identifier, failure count, error type, replay decision, and preventive fix.

