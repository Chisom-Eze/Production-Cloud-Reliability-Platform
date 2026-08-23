# Continuous Integration

## What CI Is

Continuous Integration is the practice of automatically checking every proposed code change before it is merged. For this repository, CI answers a simple question: does the current Stage 1 application still lint, test, build, and keep its local container configuration valid?

CI does not deploy anything in Stage 1.5.

## Why PR Validation Exists

Pull request validation protects `main` from changes that break the local application foundation. It gives the engineer fast feedback before merge and creates a visible audit trail of what was checked.

This matters in production because broken code, invalid container builds, or bad reverse proxy configuration should be caught before they are promoted toward deployment.

## Workflow Triggers

The workflow runs on:

- Pull requests targeting `main`.
- Pushes to `main`.

Pull request checks support review before merge. Push checks confirm that the merged state of `main` is still healthy.

## Pipeline Jobs

### Python Lint And Tests

This job:

- Checks out the repository.
- Configures Python 3.12.
- Installs application dependencies from `requirements.txt`.
- Installs CI-only tools: `pytest`, `httpx`, and `ruff`.
- Runs `ruff check application tests`.
- Runs `pytest`.

`ruff` is used because it is fast and lightweight. It is enough for Stage 1.5 without introducing a heavier quality stack.

### Docker And Nginx Checks

This job:

- Checks out the repository.
- Runs `docker compose config` to validate Compose syntax and service wiring.
- Builds the API Docker image.
- Builds the worker Docker image.
- Runs `nginx -t` inside the official Nginx image with the repository's Nginx config mounted read-only.

These checks prove that the local container definitions and Nginx configuration are structurally valid. They do not prove the full runtime behavior; that remains part of local Stage 1 verification.

## What Causes The Workflow To Fail

The workflow fails when any command exits non-zero, including:

- Python dependencies cannot install.
- `ruff` finds lint errors.
- Tests fail.
- Docker Compose configuration is invalid.
- API image build fails.
- Worker image build fails.
- Nginx configuration is invalid.

## Investigating A Failed GitHub Actions Run

Use this flow:

1. Open the pull request or commit.
2. Open the failed workflow run.
3. Identify which job failed: Python checks or Docker/Nginx checks.
4. Open the failed step and read the first concrete error.
5. Reproduce that command locally from the repository root.
6. Fix the smallest relevant issue.
7. Commit and push again.

Useful local commands:

```bash
python -m pip install -r requirements.txt
python -m pip install pytest httpx ruff
ruff check application tests
pytest
docker compose config
docker build -f application/Dockerfile.api -t production-cloud-reliability-platform-api:local .
docker build -f application/Dockerfile.worker -t production-cloud-reliability-platform-worker:local .
docker run --rm -v "$PWD/application/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro" nginx:1.27-alpine nginx -t
```

## Why CI And CD Are Separate Concerns

CI validates that a change is safe to merge. CD deploys a validated change into an environment.

They are separate because passing tests is not the same as safely changing production. Deployment needs additional controls such as environment approvals, OIDC cloud authentication, immutable image tags, smoke tests, rollback, and operational monitoring.

Stage 1.5 is CI only. AWS credentials, Terraform checks, and deployment workflows are intentionally excluded until the infrastructure stage exists.

