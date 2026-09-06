# Stage J-B Alarm And Query Catalogue

This catalogue inventories the Terraform-managed Stage J-A alarms and CloudWatch Logs Insights query definitions. It does not create duplicate alarms or dashboards.

## Alarm Severity Model

`CRITICAL` means likely or confirmed customer/business processing impact requiring immediate investigation.

`WARNING` means degradation, saturation, or precursor behavior requiring investigation but not necessarily confirmed customer impact.

Severity can differ by environment. One unhealthy target in development with desired count `1` can remove all serving capacity. One unhealthy target in a larger production service may mean degraded redundancy rather than complete outage.

## Alarm Catalogue

| Terraform Resource | AWS Alarm Name | Source Metric | Dimensions | Severity | Symptom | Does Not Prove | First Checks | Recovery Criteria |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `aws_cloudwatch_metric_alarm.dlq_visible_messages` | `${project}-${environment}-dlq-visible-messages-critical` | `AWS/SQS ApproximateNumberOfMessagesVisible` | `QueueName = dlq_name` | CRITICAL | At least one message exhausted normal processing/redrive attempts | Root cause, customer impact, or safe replayability | Inspect worker failure logs, job status, redrive count, related `correlation_id`/`job_id` logs | DLQ triaged, root cause contained, no new DLQ growth |
| `aws_cloudwatch_metric_alarm.alb_unhealthy_hosts` | `${project}-${environment}-alb-unhealthy-hosts-critical` | `AWS/ApplicationELB UnHealthyHostCount` | `LoadBalancer`, `TargetGroup` | CRITICAL | One or more registered Nginx targets are unhealthy | Whether the ALB or app generated failures | Check target health reason, ECS deployment, Nginx logs, FastAPI health, task restarts | Targets healthy and ECS service stable |
| `aws_cloudwatch_metric_alarm.api_5xx_error_rate` | `${project}-${environment}-api-5xx-error-rate-warning` | Metric math: `HTTPCode_Target_5XX_Count / RequestCount * 100` | `LoadBalancer`, `TargetGroup` | WARNING | Target-generated server errors exceed configured threshold | ALB-generated 5xx or final customer impact | Compare target 5xx vs ELB 5xx, inspect API/Nginx logs, correlate trace IDs when app was reached | Target 5xx stops and rate returns below threshold |
| `aws_cloudwatch_metric_alarm.api_p95_latency` | `${project}-${environment}-api-p95-latency-warning` | `AWS/ApplicationELB TargetResponseTime p95` | `LoadBalancer`, `TargetGroup` | WARNING | ALB-observed target latency is high | Which dependency is slow or final SLO breach | Check API Prometheus histogram, ECS CPU/memory, RDS CPU/connections, logs, traces | Latency normalizes below threshold |
| `aws_cloudwatch_metric_alarm.queue_oldest_message_age` | `${project}-${environment}-queue-oldest-message-age-warning` | `AWS/SQS ApproximateAgeOfOldestMessage` | `QueueName = queue_name` | WARNING | Queue wait/backlog age is growing | Exact end-to-end job latency | Check worker running tasks, backlog, in-flight messages, worker failures, RDS/S3/SQS dependency health | Oldest visible message age decreases and backlog drains |
| `aws_cloudwatch_metric_alarm.rds_cpu` | `${project}-${environment}-rds-cpu-warning` | `AWS/RDS CPUUtilization` | `DBInstanceIdentifier` | WARNING | Database CPU pressure | The exact query or caller causing load | Check API/worker error logs, connections, freeable memory, query/load patterns | CPU returns below threshold and dependent errors stop |
| `aws_cloudwatch_metric_alarm.rds_free_storage` | `${project}-${environment}-rds-free-storage-warning` | `AWS/RDS FreeStorageSpace` | `DBInstanceIdentifier` | WARNING | Storage is approaching configured lower bound | Immediate data loss | Check storage trend, write volume, snapshots/backups, artifact metadata growth | Free storage recovers or capacity plan is executed |

## Correlated Metrics

Use these supporting metrics during triage:

- Edge: `RequestCount`, `HTTPCode_Target_5XX_Count`, `HTTPCode_ELB_5XX_Count`, `TargetResponseTime`, `UnHealthyHostCount`
- ECS: `CpuUtilized`, `MemoryUtilized`, `RunningTaskCount`, desired task count
- Queue: `ApproximateNumberOfMessagesVisible`, `ApproximateNumberOfMessagesNotVisible`, `ApproximateAgeOfOldestMessage`
- Database: `CPUUtilization`, `DatabaseConnections`, `FreeStorageSpace`, `FreeableMemory`
- Application: `app_http_requests_total`, `app_http_request_duration_seconds`, `app_errors_total`
- Worker: `worker_jobs_processed_total`, `worker_job_processing_duration_seconds`, `worker_outbox_dispatch_total`, `worker_duplicate_jobs_total`, `worker_job_claims_total`, `worker_outbox_reclaims_total`, `worker_visibility_heartbeat_failures_total`

## Terraform-Managed Logs Insights Queries

| Terraform Resource | Query Name | Log Groups | Use |
| --- | --- | --- | --- |
| `aws_cloudwatch_query_definition.api_errors` | `${project}-${environment}/api/errors` | API and Nginx log groups | Find API/Nginx 5xx or error records in a time window |
| `aws_cloudwatch_query_definition.worker_failures` | `${project}-${environment}/worker/failures` | Worker log group | Find worker failure records and job context |
| `aws_cloudwatch_query_definition.correlation_lookup` | `${project}-${environment}/correlation/request-lookup` | API, Nginx, worker log groups | Follow a `request_id` or `correlation_id` across components |
| `aws_cloudwatch_query_definition.trace_lookup` | `${project}-${environment}/trace/trace-id-lookup` | API, Nginx, worker log groups | Find logs connected to a known `trace_id` |

The JSON logging schema supports `timestamp`, `level`, `service`, `message`, `request_id`, `correlation_id`, `trace_id`, `span_id`, and selected contextual fields such as `method`, `path`, `status_code`, `latency_ms`, `error`, and `job_id`.

Do not add `job_id`, `request_id`, `correlation_id`, `trace_id`, `span_id`, raw URLs, S3 object keys, customer IDs, UUIDs, or exception messages as metric labels.

