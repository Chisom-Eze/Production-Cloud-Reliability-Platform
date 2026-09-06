# Runbook: SQS Backlog Or Oldest Message Growth

## SYMPTOM

`ApproximateNumberOfMessagesVisible` or `ApproximateAgeOfOldestMessage` grows and does not recover.

## CUSTOMER/BUSINESS IMPACT

Accepted jobs may wait longer before report generation completes.

## PRIMARY SIGNAL

`${project}-${environment}-queue-oldest-message-age-warning` and SQS main queue metrics.

## SUPPORTING SIGNALS

Worker `RunningTaskCount`, worker autoscaling target tracking, `worker_jobs_processed_total`, `worker_job_processing_duration_seconds`, worker logs, RDS metrics, and S3 artifact write evidence.

## FIRST CHECKS

Confirm worker service is running, backlog is visible rather than only in-flight, worker failures are not increasing, and downstream dependencies are healthy.

## CORRELATION PATH

Start with queue metrics, then worker logs and worker Prometheus metrics. Use `correlation_id` or `job_id` in logs to inspect representative jobs.

## LIKELY CAUSES

Worker unavailable, processing failures, slow database or S3 operations, insufficient worker capacity, downstream API latency, or traffic spike beyond current scaling limits.

## SAFE MITIGATION OPTIONS

Allow autoscaling to respond, scale worker capacity if saturation is confirmed, restore a healthy worker revision, or remediate the slow dependency.

## RECOVERY CRITERIA

Oldest message age decreases, visible backlog drains, worker success rate returns to normal, and no new DLQ messages appear.

## ESCALATION / FOLLOW-UP

Capture arrival rate, processing rate, worker count, average processing time, and whether autoscaling target values need adjustment.

