# Stage J-B SLI And SLO Contract

Stage J-B operationalizes the Stage J-A telemetry foundation. It defines how engineers interpret existing metrics, logs, traces, alarms, and dashboards without declaring final business SLO targets.

Runtime validation in AWS has not occurred yet. The implementation is currently locally and statically validated only.

## SLI Catalogue

| Signal | Service | Outcome | Telemetry Source | Metric Or Query | Good Event | Bad Event | Classification | SLO Now? | Additional Evidence Required |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| API availability | API | Users can receive server responses from the API path | ALB CloudWatch metrics and API Prometheus metrics | `RequestCount`, `HTTPCode_Target_5XX_Count`, `app_http_requests_total{status_class=...}` | Eligible request does not produce server 5xx | Eligible request produces server 5xx | DIRECT SLI | No | Business target, measurement window, exclusions, traffic baseline |
| API error rate | API | Server-side failures remain controlled | ALB CloudWatch metrics, API logs | `HTTPCode_Target_5XX_Count / RequestCount`, `app_http_requests_total` | Non-5xx server response | Target-generated or app-generated 5xx | DIRECT SLI | No | Error-rate target and paging policy |
| API latency | API | Users receive timely responses | Prometheus histogram, ALB supporting metric | `app_http_request_duration_seconds`, `TargetResponseTime` | Eligible request completes under future threshold T | Eligible request exceeds future threshold T | DIRECT SLI | No | Threshold T from business and load-test evidence |
| API saturation | API/ECS | Capacity pressure is visible | CloudWatch ECS and ALB metrics | CPU, memory, running tasks, desired tasks, healthy targets | Capacity within expected operating range | Sustained pressure or loss of serving capacity | SUPPORTING DIAGNOSTIC SIGNAL | No | Capacity model and load-test data |
| Job processing success | Worker | Accepted durable jobs complete successfully | Worker Prometheus metrics | `worker_jobs_processed_total{result=...}` | Terminal processing attempt completes and records artifact result | Terminal processing attempt fails | DIRECT SLI | No | Job classes, acceptable failure policy, retry accounting |
| Job processing latency | Worker | Async jobs complete within expected time | Worker Prometheus histogram | `worker_job_processing_duration_seconds` | Terminal processing attempt completes under future threshold T | Terminal processing attempt exceeds threshold T | DIRECT SLI | No | Business delay target and processing distribution |
| Queue waiting health | SQS/Worker | Async work is not waiting too long | SQS CloudWatch metric | `ApproximateAgeOfOldestMessage` | Oldest visible message age stays within future bound | Oldest visible message age exceeds bound | OPERATIONAL PROXY | No | End-to-end job wait model and acceptable delay |
| Queue backlog | SQS/Worker | Backpressure and saturation are visible | SQS CloudWatch metric | `ApproximateNumberOfMessagesVisible` | Backlog stays within capacity envelope | Backlog grows faster than workers drain it | SUPPORTING DIAGNOSTIC SIGNAL | No | Arrival rate, processing rate, autoscaling target |
| DLQ occurrence | SQS/Worker | Retries are exhausted for at least one message | SQS CloudWatch metric | DLQ `ApproximateNumberOfMessagesVisible` | DLQ remains empty | DLQ visible count is greater than zero | OPERATIONAL PROXY | No | Replay policy and customer impact mapping |
| Reliability controls | Worker | Retry/fencing/idempotency controls are behaving | Worker Prometheus metrics and logs | `worker_duplicate_jobs_total`, `worker_job_claims_total`, `worker_outbox_reclaims_total`, `worker_visibility_heartbeat_failures_total`, `worker_outbox_dispatch_total` | Expected bounded control events | Sustained failures, reclaims, or heartbeat failures | SUPPORTING DIAGNOSTIC SIGNAL | No | Normal baseline under real workload |

## API Availability Model

API availability is measured as successful server responses divided by eligible requests. Server-generated 5xx responses are bad events. Normal client 4xx responses are not availability failures unless a later business requirement says otherwise.

Boundary cases:

- WAF rejections are edge/security policy outcomes, not API target availability failures.
- Malformed client requests are excluded unless the product defines them as supported traffic.
- Future authentication or authorization failures should be classified explicitly before inclusion.
- Nginx returning 502 because FastAPI is unavailable is target-generated 5xx because Nginx is the ALB target.

## API Error-Rate Model

API error rate is server 5xx divided by eligible requests. Engineers must keep ALB-generated and target-generated 5xx separate:

- `HTTPCode_Target_5XX_Count` means the registered target returned the 5xx. For this project, the target is Nginx.
- `HTTPCode_ELB_5XX_Count` means the load balancer itself generated the 5xx.

Do not merge those symptoms in incident analysis.

## API Latency Model

Prometheus application histograms support p50, p95, and p99 from `app_http_request_duration_seconds`. CloudWatch ALB `TargetResponseTime` remains an AWS-side supporting signal.

A future latency SLO must be stated as a percentage of eligible requests under threshold T seconds over a measurement window. T must come from user experience, business, or performance evidence.

## Async Job Models

Job processing success is successful terminal processing attempts divided by terminal processing attempts. Duplicates ignored due to idempotency are not automatically business failures and should not be placed in the denominator unless the future policy says so.

Job latency uses `worker_job_processing_duration_seconds` and can support p50, p95, and p99. Queue age is a strong operational proxy for waiting health, but SQS `ApproximateAgeOfOldestMessage` is not exact per-job end-to-end latency.

## Database Operating Signals

PostgreSQL signals are infrastructure health and saturation indicators, not customer-facing SLIs:

- `CPUUtilization`: high values can produce API and worker latency or throughput degradation.
- `DatabaseConnections`: saturation can cause readiness failures, API database errors, or worker failures.
- `FreeStorageSpace`: low storage threatens writes and durable job/artifact metadata.
- `FreeableMemory`: sustained pressure can degrade query performance.

No absolute production threshold is declared in this document.

## SLO Definition Methodology

Every future SLO requires:

- business requirement
- service or user journey
- selected SLI
- target
- measurement window
- exclusions
- error-budget policy
- response when budget is exhausted

This stage intentionally does not declare 99.9 percent, 99.95 percent, 99.99 percent, or any other final objective.

## Error Budget Model

If an availability SLO is `S`, the allowed bad fraction is `1 - S`. The error budget for a measurement window derives from that allowed bad fraction and the eligible event count during the window.

Burn rate is:

```text
observed bad-event rate / allowed bad-event rate
```

A burn rate greater than `1` means the service is consuming error budget faster than the long-term allowed rate.

Burn-rate alarms are not created yet. They require an agreed SLO target, measurement windows, paging policy, and business approval. Future hardening can add multi-window, multi-burn-rate alerting.

## Direct SLI Vs Proxy Classification

Direct SLIs:

- API availability
- API target/app error rate
- API latency
- job processing success
- job processing latency

Operational proxies:

- queue oldest visible message age
- DLQ visible messages

Supporting diagnostics:

- API CPU, memory, running tasks, desired tasks, healthy target count
- queue visible and in-flight message counts
- worker duplicate, claim, reclaim, outbox, heartbeat metrics
- RDS CPU, connections, storage, and memory

