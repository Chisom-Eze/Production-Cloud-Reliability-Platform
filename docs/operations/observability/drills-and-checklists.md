# Stage J-B Drills And Checklists

These drills are specifications only. Do not execute them during Stage J-B.

## Controlled Nginx 502 Drill

Scope: development only.

Target failure:

```text
ALB -> Nginx -> invalid/unreachable FastAPI upstream -> 502
```

Preferred future mechanism: deploy a deliberately bad development task revision or configuration that points Nginx to an invalid upstream host or port. Do not mutate production. Do not change stable application source solely for the drill.

Expected failure chain:

1. New API task revision starts.
2. Nginx process may remain alive.
3. FastAPI may remain healthy depending on the injected fault.
4. Nginx cannot reach the FastAPI upstream.
5. Requests through Nginx return 502.
6. ALB `/health` through Nginx fails.
7. Target becomes unhealthy.
8. ECS deployment cannot reach steady state.
9. ECS deployment circuit breaker detects the failed deployment.
10. ECS rolls back to the last completed task definition where applicable.

Expected telemetry:

- ALB `HTTPCode_Target_5XX_Count` increases.
- ALB `UnHealthyHostCount` increases when health checks fail.
- ECS desired/running/pending task counts show deployment instability.
- ECS deployment events show failure or rollback behavior.
- Nginx logs show upstream/connectivity errors.
- Unhealthy target and/or 5xx alarms move state where configured thresholds allow.
- Grafana edge and ECS views show the blast radius.
- FastAPI Prometheus metrics may not show the 502 if FastAPI never receives the request.
- X-Ray may not contain an application trace when Nginx generates the 502 before the app receives traffic.

Mandatory distinction:

- A 502 returned by Nginx is target-generated because Nginx is the ALB target.
- Do not call it `HTTPCode_ELB_5XX_Count` unless evidence shows the ALB itself generated the error.

Drill success criteria:

1. Failure injected intentionally.
2. Customer-visible symptom observed.
3. Correct CloudWatch metric moved.
4. Correct alarm changed state where threshold allows.
5. Log evidence identified root failure.
6. Metric/log/trace expectations matched the failure boundary.
7. ECS rollback or recovery behavior observed.
8. Healthy service restored.
9. Target health restored.
10. Alarms return to OK.
11. No data corruption occurred.
12. Incident timeline can be reconstructed.

## Async Worker/SQS Failure Drill

Scope: development only.

Example future fault: make worker processing fail safely for a known test job.

Expected failure chain:

1. SQS message is received.
2. Processing fails.
3. Message is not deleted.
4. Visibility timeout expires.
5. SQS redelivers.
6. Retry repeats while failure persists.
7. Message moves to DLQ after max receive count.

Expected telemetry:

- `worker_jobs_processed_total{result="failure"}` increases.
- Worker logs include job context.
- SQS visible and in-flight metrics change.
- `ApproximateAgeOfOldestMessage` may grow.
- DLQ `ApproximateNumberOfMessagesVisible` becomes greater than zero after redrive exhaustion.
- Job fencing and retry behavior prevent unsafe duplicate completion.

Do not use a production data mutation mechanism for this drill.

## Deployment Observability Checklist

Before declaring the first AWS deployment healthy, verify:

- ECS cluster available.
- API service stable.
- Worker service stable.
- desired task count equals running task count.
- no unexpected task restart loop.
- ALB targets healthy.
- `/health` passes through the ALB.
- HTTPS request succeeds.
- API `/health`, `/ready`, and `/metrics` behave as expected.
- Worker service is running.
- outbox dispatch is operational.
- SQS consumption is operational.
- RDS connections are healthy and no immediate resource pressure exists.
- SQS main queue is accessible.
- DLQ is empty initially.
- S3 artifact path works.
- CloudWatch logs are arriving.
- Container Insights data is present.
- CloudWatch alarms exist.
- AMP metrics are arriving.
- X-Ray sampled traces are arriving.
- Grafana CloudWatch, AMP, and X-Ray data sources work.
- A `trace_id` in an application log can be matched to X-Ray where a trace exists.

## Alarm Testing Checklist

Every alarm should eventually be proven through:

- signal generation
- alarm transition
- notification path
- diagnosis
- recovery
- OK transition

The SNS alarm topic currently has no invented subscription endpoint. Notification delivery cannot be considered fully tested until a real subscriber or incident-management integration is configured.

## Observability Maturity Matrix

| Capability | Status |
| --- | --- |
| application metrics | IMPLEMENTED + LOCALLY/STATICALLY VALIDATED |
| structured logs | IMPLEMENTED + LOCALLY/STATICALLY VALIDATED |
| trace correlation | IMPLEMENTED + LOCALLY/STATICALLY VALIDATED |
| ADOT task definitions | IMPLEMENTED + LOCALLY/STATICALLY VALIDATED |
| AMP Terraform | IMPLEMENTED + LOCALLY/STATICALLY VALIDATED |
| X-Ray export contract | IMPLEMENTED + LOCALLY/STATICALLY VALIDATED |
| Amazon Managed Grafana Terraform | IMPLEMENTED + LOCALLY/STATICALLY VALIDATED |
| CloudWatch alarms | IMPLEMENTED + LOCALLY/STATICALLY VALIDATED |
| CloudWatch dashboard | IMPLEMENTED + LOCALLY/STATICALLY VALIDATED |
| Logs Insights definitions | IMPLEMENTED + LOCALLY/STATICALLY VALIDATED |
| ADOT to AMP remote write | NOT YET RUNTIME-PROVEN IN AWS |
| ADOT to X-Ray export | NOT YET RUNTIME-PROVEN IN AWS |
| Grafana datasource connectivity | NOT YET RUNTIME-PROVEN IN AWS |
| CloudWatch alarm behavior under real failures | NOT YET RUNTIME-PROVEN IN AWS |
| ECS rollback telemetry | NOT YET RUNTIME-PROVEN IN AWS |
| actual load behavior | NOT YET RUNTIME-PROVEN IN AWS |
| final SLO thresholds | NOT YET RUNTIME-PROVEN IN AWS |
| error-budget policy | NOT YET RUNTIME-PROVEN IN AWS |
| notification delivery | NOT YET RUNTIME-PROVEN IN AWS |

