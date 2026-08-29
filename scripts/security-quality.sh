#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="${REPORT_DIR:-$(mktemp -d)}"
COMMIT_SHA="${GITHUB_SHA:-$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo local)}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    echo "Install required tools before running this script: bandit, pip-audit, gitleaks, trivy, docker." >&2
    exit 2
  fi
}

run_hadolint() {
  local dockerfile="$1"
  local output="$2"

  if command -v hadolint >/dev/null 2>&1; then
    hadolint --failure-threshold error -f json "$dockerfile" > "$output"
  elif command -v docker >/dev/null 2>&1; then
    docker run --rm -i hadolint/hadolint:v2.15.1 hadolint --failure-threshold error -f json - < "$dockerfile" > "$output"
  else
    echo "missing required command: hadolint or docker" >&2
    echo "Install native hadolint or ensure Docker is available for the hadolint/hadolint:v2.15.1 fallback." >&2
    exit 2
  fi
}

echo "Security quality gates are read-only against source code."
echo "Report directory: ${REPORT_DIR}"

require_command bandit
require_command pip-audit
require_command gitleaks
require_command trivy
require_command docker

mkdir -p "$REPORT_DIR"

cd "$REPO_ROOT"

echo "==> Bandit Python SAST"
bandit -r application \
  -ll \
  -ii \
  -f json \
  -o "$REPORT_DIR/bandit.json"

echo "==> pip-audit dependency scan"
pip-audit -r requirements.txt \
  --format json \
  --output "$REPORT_DIR/pip-audit.json"

echo "==> Gitleaks secret scan with redacted output"
gitleaks detect \
  --source "$REPO_ROOT" \
  --redact \
  --no-banner \
  --report-format json \
  --report-path "$REPORT_DIR/gitleaks.json"

echo "==> Hadolint Dockerfile analysis"
run_hadolint application/Dockerfile.api "$REPORT_DIR/hadolint-api.json"
run_hadolint application/Dockerfile.nginx "$REPORT_DIR/hadolint-nginx.json"
run_hadolint application/Dockerfile.worker "$REPORT_DIR/hadolint-worker.json"

API_IMAGE="production-cloud-reliability-api:${COMMIT_SHA}"
WORKER_IMAGE="production-cloud-reliability-worker:${COMMIT_SHA}"
NGINX_IMAGE="production-cloud-reliability-nginx:${COMMIT_SHA}"

echo "==> Build local CI-only images"
docker build -f application/Dockerfile.api -t "$API_IMAGE" .
docker build -f application/Dockerfile.worker -t "$WORKER_IMAGE" .
docker build -f application/Dockerfile.nginx -t "$NGINX_IMAGE" .

echo "==> Trivy image visibility scan"
trivy image --severity HIGH,CRITICAL --format json --output "$REPORT_DIR/trivy-api-all.json" --exit-code 0 "$API_IMAGE"
trivy image --severity HIGH,CRITICAL --format json --output "$REPORT_DIR/trivy-worker-all.json" --exit-code 0 "$WORKER_IMAGE"
trivy image --severity HIGH,CRITICAL --format json --output "$REPORT_DIR/trivy-nginx-all.json" --exit-code 0 "$NGINX_IMAGE"

echo "==> Trivy image blocking scan"
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$API_IMAGE"
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$WORKER_IMAGE"
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$NGINX_IMAGE"

echo "Security quality gates passed."
