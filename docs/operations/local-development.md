# Local Development

## What We Are Building

Stage 1 adds a local FastAPI API, a PostgreSQL schema, and an SQS-compatible worker foundation using LocalStack.

## Why It Exists In Production

Local development should exercise the same operational patterns used later in AWS: dependency checks, database transactions, asynchronous job creation, queue consumption, structured logs, and request correlation.

The local stack does not replace AWS. It gives engineers a fast feedback loop before infrastructure and deployment automation are introduced.

## Files Created Or Changed

- `pyproject.toml`
- `.env.example`
- `docker-compose.yml`
- `services/platform_app/api/main.py`
- `services/platform_app/api/schemas.py`
- `services/platform_app/config.py`
- `services/platform_app/db/database.py`
- `services/platform_app/db/repository.py`
- `services/platform_app/db/migrations/001_initial_schema.sql`
- `services/platform_app/logging.py`
- `services/platform_app/queue.py`
- `services/platform_app/worker/main.py`
- `tests/test_api.py`
- `tests/test_worker.py`

## How It Works

The API exposes:

- `GET /health`
- `GET /ready`
- `GET /customers`
- `POST /customers`
- `GET /jobs`
- `POST /jobs`
- `GET /jobs/{id}`

`/health` proves the process is alive. `/ready` checks whether the API can reach PostgreSQL and SQS.

Customer creation writes to `customers` and `audit_events` in one database transaction.

Job creation writes a `pending` row to `jobs` and sends the job ID to SQS. The worker receives the message, marks the job `processing`, writes a result, marks it `completed`, and deletes the SQS message only after durable database work succeeds.

Structured logs include request IDs and correlation IDs so an operator can connect API requests to worker activity.

## How To Run It

Install Python 3.11 or newer, then from the repository root:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env
docker compose up -d postgres localstack
```

Start the API:

```bash
PYTHONPATH=services uvicorn platform_app.api.main:app --reload --host 0.0.0.0 --port 8000
```

Start the worker in another shell:

```bash
PYTHONPATH=services python -m platform_app.worker.main
```

On Windows PowerShell, use:

```powershell
$env:PYTHONPATH="services"
uvicorn platform_app.api.main:app --reload --host 0.0.0.0 --port 8000
```

## How To Verify It

Run unit tests:

```bash
pytest
```

Check process health:

```bash
curl http://localhost:8000/health
```

Check dependency readiness:

```bash
curl http://localhost:8000/ready
```

Create a customer:

```bash
curl -X POST http://localhost:8000/customers \
  -H "content-type: application/json" \
  -H "x-correlation-id: demo-local-001" \
  -d '{"name":"Ada Lovelace","email":"ada@example.com"}'
```

Create a job:

```bash
curl -X POST http://localhost:8000/jobs \
  -H "content-type: application/json" \
  -H "x-correlation-id: demo-local-002" \
  -d '{"job_type":"demo","payload":{"source":"local"}}'
```

List jobs:

```bash
curl http://localhost:8000/jobs
```

## What Can Fail

- PostgreSQL is not running, so `/ready` returns `503`.
- LocalStack is not running, so job submission or readiness fails.
- Duplicate customer email returns `409`.
- Worker can process a message but fail before deleting it, so SQS may redeliver it.
- A completed job may be redelivered; the worker treats completed jobs as duplicates and ignores them.
- Invalid database credentials produce startup or readiness failures.

## Interview Questions

- Why does `/health` not check the database?
- Why should `/ready` check dependencies?
- Why does customer creation use a transaction?
- Why is the database job row the source of truth instead of the SQS message?
- Why does the worker delete the SQS message only after completing database work?
- How does this worker handle duplicate SQS delivery?
- What evidence would you inspect if jobs stay `pending`?
- What would happen if PostgreSQL becomes unavailable during job processing?

