# Stage 1 Local Application

## What We Are Building

Stage 1 builds a local vertical slice:

```text
Client
  -> Nginx
  -> FastAPI
  -> PostgreSQL
```

It also creates the asynchronous job interface that later becomes SQS-backed and the artifact adapter shape that later becomes S3-backed.

## Why It Exists In Production

Before introducing AWS, the application must prove the basic production behaviors locally: reverse proxying, health checks, readiness checks, database migrations, structured logs, request correlation, Prometheus metrics, and a clear async job boundary.

## What Works Locally In Stage 1

- Nginx reverse proxies to FastAPI through Docker networking.
- FastAPI exposes `/health`, `/ready`, `/customers`, `/jobs/{id}`, and `/metrics`.
- PostgreSQL stores `customers`, `jobs`, `job_results`, `audit_events`, and `object_metadata`.
- Migrations are mounted into the Postgres container and run at database initialization.
- `POST /jobs` creates a pending job in PostgreSQL and publishes the job ID through a local adapter.
- Worker foundation can process a job if called by code, generate CSV report metadata, and use the future object key pattern.
- Logs are structured JSON in the API and structured access logs in Nginx.
- Prometheus metrics are exposed at `/metrics`.

## What Becomes AWS-Backed Later

- Local job publisher becomes SQS producer.
- Worker idle foundation becomes SQS polling worker.
- Local artifact store becomes S3 artifact store.
- Local Docker Compose becomes ECS services.
- Local Postgres becomes RDS PostgreSQL.
- Local Nginx container becomes ECS sidecar in the API task.

## Request Path

```text
curl http://localhost:8080/health
  -> Docker published port 8080
  -> Nginx container
  -> Docker DNS name api
  -> FastAPI container port 8000
  -> API response
```

For database-backed requests:

```text
curl http://localhost:8080/customers
  -> Nginx
  -> FastAPI route
  -> service/repository
  -> PostgreSQL connection pool
  -> SQL query or transaction
```

## Liveness Vs Readiness

`/health` proves the process is alive. It should not depend on PostgreSQL because a process can be alive while a dependency is down.

`/ready` proves the application is ready to serve real traffic. It checks PostgreSQL connectivity and returns `503` when the database is unavailable.

This distinction matters in production because an orchestrator can keep a process alive while removing it from traffic until dependencies recover.

## Docker Networking

Docker Compose creates a shared network for the services. Nginx reaches FastAPI with `proxy_pass http://api:8000` because `api` is the Compose service name and Docker provides internal DNS.

## PostgreSQL Connection Lifecycle

The API creates a connection pool during FastAPI lifespan startup and closes it during shutdown. Requests borrow connections for short transactions and return them to the pool when the transaction context exits.

## Migrations

Stage 1 uses SQL migrations in `application/shared/migrations`. They are mounted into `/docker-entrypoint-initdb.d` so the Postgres image applies them when the database volume is first initialized.

In later stages, migrations should be run explicitly during deployment rather than relying on application startup to create tables.

## Structured Logging And Correlation IDs

Nginx generates or forwards `x-request-id` and `x-correlation-id`. FastAPI propagates them through request context and includes them in JSON logs.

During an incident, use one correlation ID to search Nginx access logs and API logs for the same request path, status, latency, and error.

## Prometheus Metrics

`/metrics` exposes scrapeable metrics for:

- HTTP request count
- HTTP request duration
- HTTP response status
- Application errors

Prometheus is not deployed in Stage 1.

## Nginx 502 Vs 504

Nginx can return `502` when it cannot connect to the upstream FastAPI container, for example a wrong service name or port.

Nginx can return `504` when it connects but the upstream does not respond before the proxy timeout.

## Container Health Checks

- API health check calls `/health` on port 8000.
- Nginx health check calls `/health` through the proxy on port 8080.
- Postgres health check uses `pg_isready`.

## Graceful Shutdown

FastAPI closes the database pool during lifespan shutdown. The worker installs SIGINT/SIGTERM handlers and exits its idle loop cleanly.

## Manual SQL

Run:

```bash
docker compose exec postgres psql -U platform -d platform -f /docker-entrypoint-initdb.d/001_initial_schema.sql
docker compose exec postgres psql -U platform -d platform
```

Useful queries are stored in `application/shared/sql/inspection.sql`.

## Verification Commands

```bash
docker compose up --build -d
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -X POST http://localhost:8080/customers \
  -H "content-type: application/json" \
  -H "x-correlation-id: demo-stage1" \
  -d '{"name":"Ada Lovelace","email":"ada@example.com"}'
curl http://localhost:8080/customers
curl -X POST http://localhost:8080/jobs \
  -H "content-type: application/json" \
  -H "x-correlation-id: demo-stage1-job" \
  -d '{"job_type":"csv_report","payload":{"scope":"customers"}}'
curl http://localhost:8080/metrics
docker compose logs nginx
docker compose logs api
```

Mandatory readiness drill:

```bash
docker compose stop postgres
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
docker compose start postgres
```

