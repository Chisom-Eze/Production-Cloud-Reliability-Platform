# Runbook: API Elevated 5xx Or 502

## SYMPTOM

CloudWatch reports elevated target 5xx, users receive 5xx responses, or the ALB target group marks API targets unhealthy.

## CUSTOMER/BUSINESS IMPACT

Users may be unable to create customers, create jobs, or retrieve job status.

## PRIMARY SIGNAL

`HTTPCode_Target_5XX_Count`, `${project}-${environment}-api-5xx-error-rate-warning`, and `${project}-${environment}-alb-unhealthy-hosts-critical`.

## SUPPORTING SIGNALS

`HTTPCode_ELB_5XX_Count`, `TargetResponseTime`, `UnHealthyHostCount`, ECS task health, Nginx logs, API logs, `app_http_requests_total`, `app_errors_total`, and X-Ray traces when FastAPI receives the request.

## FIRST CHECKS

Separate target-generated 5xx from ALB-generated 5xx. Check ALB target health reason codes, ECS service events, Nginx logs, API logs, task restart count, and database readiness symptoms.

## CORRELATION PATH

Use `${project}-${environment}/api/errors`, then `request_id`, `correlation_id`, or `trace_id` with the correlation and trace lookup queries. If no app trace exists for a Nginx 502, treat that absence as evidence that the request likely failed before FastAPI execution.

## LIKELY CAUSES

Bad Nginx upstream, FastAPI task unavailable, failed deployment, application exception, database outage causing server errors, overloaded task, or ALB target health failure.

## SAFE MITIGATION OPTIONS

Allow ECS circuit breaker rollback, restore a previous healthy task revision, scale API service if saturation is confirmed, or remediate the dependency causing failures.

## RECOVERY CRITERIA

Target 5xx stops, target health returns healthy, API service stabilizes, latency normalizes, and alarms return to OK.

## ESCALATION / FOLLOW-UP

Capture root cause, affected request window, whether traces existed, whether rollback occurred, and preventive changes.

