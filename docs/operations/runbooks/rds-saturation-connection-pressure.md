# Runbook: RDS Saturation Or Connection Pressure

## SYMPTOM

RDS CPU, connections, storage, or freeable memory indicate sustained pressure. API readiness, API writes, or worker processing may fail.

## CUSTOMER/BUSINESS IMPACT

User requests may become slow or fail, job creation can fail, worker completion can fail, and durable state writes may be at risk.

## PRIMARY SIGNAL

`${project}-${environment}-rds-cpu-warning`, `${project}-${environment}-rds-free-storage-warning`, `DatabaseConnections`, and `FreeableMemory`.

## SUPPORTING SIGNALS

API `/ready`, API database error logs, worker failure logs, API latency, worker processing latency, ECS scaling, and sampled database spans in X-Ray when available.

## FIRST CHECKS

Determine whether pressure is CPU, connections, storage, or memory. Check whether API and worker errors began at the same time and whether traffic or queue processing spiked.

## CORRELATION PATH

Use RDS metrics to scope the database symptom, then API/worker logs for affected operations. Use X-Ray sampled traces for application-to-database timing when present.

## LIKELY CAUSES

Traffic spike, worker backlog drain creating write pressure, connection saturation, inefficient query, storage growth, or undersized development instance.

## SAFE MITIGATION OPTIONS

Reduce rollout pressure, restore stable workload revision, scale application workers carefully if the bottleneck is not the database, or execute an approved database capacity change.

## RECOVERY CRITERIA

Database metrics return to expected range, API readiness stabilizes, API/worker database errors stop, and queue/job processing recovers.

## ESCALATION / FOLLOW-UP

Capture metric timeline, affected operations, connection trend, query evidence where available, and capacity or pooling recommendations.

