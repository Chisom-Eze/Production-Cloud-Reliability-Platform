# Runbook: ECS Unhealthy Targets Or Deployment Failure

## SYMPTOM

ECS service cannot reach steady state, tasks restart, deployment circuit breaker rolls back, or ALB reports unhealthy targets.

## CUSTOMER/BUSINESS IMPACT

API capacity may be reduced or unavailable. Worker capacity may fall behind async demand.

## PRIMARY SIGNAL

ECS service events, `RunningTaskCount`, desired task count, `UnHealthyHostCount`, and `${project}-${environment}-alb-unhealthy-hosts-critical`.

## SUPPORTING SIGNALS

Container logs, Nginx logs, API health check behavior, task definition revision, image digest, CPU, memory, pending tasks, and deployment event history.

## FIRST CHECKS

Check which service is affected, whether the failure is task start, container health, ALB health, image pull, secret injection, or runtime crash. Confirm desired and running task counts.

## CORRELATION PATH

Use CloudWatch service metrics to scope the failure, then inspect API/Nginx/worker log groups and ECS deployment events. Use traces only if requests reached FastAPI or worker spans were emitted.

## LIKELY CAUSES

Bad image digest, failed migration release sequence, invalid Nginx upstream, missing secret injection, container crash, health check failure, insufficient CPU/memory, network dependency failure, or security-group misconfiguration.

## SAFE MITIGATION OPTIONS

Let ECS circuit breaker rollback complete, redeploy the last known-good task definition, pause rollout, or adjust capacity if saturation is confirmed.

## RECOVERY CRITERIA

Deployment reaches steady state, desired equals running tasks, unhealthy targets clear, restart loop stops, and service logs show normal operation.

## ESCALATION / FOLLOW-UP

Record failed task definition, image digest, event timeline, health check result, and rollback outcome.

