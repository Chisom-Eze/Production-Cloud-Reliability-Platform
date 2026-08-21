# Data Flow

## What We Are Building

The first-pass request, persistence, asynchronous job, object storage, and observability data flows.

## Why It Exists In Production

Data flow documentation helps engineers troubleshoot failures by showing where data moves, which component owns each operation, and where evidence should appear during an incident.

## API Request Flow

```text
Client
  -> Route 53 DNS resolution
  -> Application Load Balancer
  -> Nginx sidecar in ECS API task
  -> FastAPI container
  -> PostgreSQL query or transaction
  -> Structured API and Nginx log events
  -> HTTP response
```

Expected evidence:

- ALB metrics show request volume, latency, and status codes.
- Nginx access logs show edge-to-upstream behavior.
- API logs show request ID, endpoint, latency, status code, and errors.
- RDS metrics show connections, CPU, storage, and query pressure.
- Prometheus metrics show application request counts, latency, 4xx, 5xx, and active requests.

## Customer Creation Flow

```text
Client
  -> POST /customers
  -> ALB
  -> Nginx
  -> FastAPI validates payload
  -> FastAPI opens database transaction
  -> FastAPI inserts customer row
  -> FastAPI writes audit event
  -> FastAPI commits transaction
  -> FastAPI returns created customer
```

Important behavior:

- Customer creation should be transactional with audit event creation.
- Failed validation should return 4xx.
- Database failure should return a controlled 5xx and log the root error safely.

## Job And S3 Artifact Flow

```text
Client
  -> POST /jobs
  -> API validates payload
  -> API creates job row with pending status in PostgreSQL
  -> API sends SQS message with job ID
  -> API returns accepted job response
  -> Worker polls SQS
  -> Worker validates job state in PostgreSQL
  -> Worker generates report/export/artifact
  -> Worker uploads object to S3
  -> Worker stores S3 object key and metadata in PostgreSQL
  -> Worker writes job result
  -> Worker marks job completed
  -> Worker deletes SQS message
```

Important behavior:

- PostgreSQL is the source of truth for transactional state.
- S3 stores durable objects, not relational state.
- SQS message deletion happens only after durable processing succeeds.
- If S3 upload succeeds but PostgreSQL update fails, the system may create an orphaned object that needs reconciliation.
- If PostgreSQL update succeeds but SQS deletion fails, SQS may redeliver the message and the worker must process idempotently.

## Worker Processing Flow

```text
SQS queue
  -> Worker polls message
  -> Worker extracts job ID
  -> Worker checks current job status
  -> Worker marks job processing
  -> Worker performs idempotent work
  -> Worker uploads artifact to S3 if required
  -> Worker writes object metadata and result to PostgreSQL
  -> Worker marks job completed
  -> Worker deletes SQS message
```

Important behavior:

- SQS can deliver messages more than once.
- Worker logic must tolerate duplicates.
- S3 object keys should be deterministic or otherwise linked to job IDs to support idempotency.
- Failed messages should become visible again or move to a dead-letter queue after configured retries.

## Readiness Flow

```text
ALB or operator
  -> Nginx health path
  -> FastAPI /ready
  -> API checks database connectivity
  -> API checks required configuration
  -> API checks SQS access where practical
  -> API checks S3 access where practical
  -> API returns ready or not ready
```

Important behavior:

- `/health` should be lightweight and prove the process is alive.
- `/ready` should prove the service can handle real traffic.
- Readiness failures should produce actionable logs.

## Observability Flow

```text
API, worker, Nginx
  -> Structured logs
  -> CloudWatch Logs

AWS services
  -> CloudWatch metrics, alarms, dashboards

API and worker metrics
  -> Prometheus
  -> Grafana

AWS API activity
  -> CloudTrail
```

Important behavior:

- CloudWatch is the central AWS-native operations surface.
- Prometheus/Grafana are for service-level metrics and dashboarding.
- OpenTelemetry tracing is a later enhancement unless implementation time allows.
