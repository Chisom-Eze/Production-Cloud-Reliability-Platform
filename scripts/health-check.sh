#!/usr/bin/env sh
set -eu

usage() {
  echo "usage: $0 BASE_URL" >&2
  echo "example: $0 http://localhost:8080" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

BASE_URL="${1%/}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 2
fi

health_body="$(curl -fsS "$BASE_URL/health")" || {
  echo "health check failed" >&2
  exit 1
}

ready_status="$(curl -sS -o /tmp/platform-ready.json -w "%{http_code}" "$BASE_URL/ready")" || {
  echo "readiness request failed" >&2
  exit 1
}

echo "health: $health_body"
echo "ready_status: $ready_status"

if [ "$ready_status" != "200" ]; then
  echo "readiness body:" >&2
  sed 's/^/  /' /tmp/platform-ready.json >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  jq . /tmp/platform-ready.json
else
  cat /tmp/platform-ready.json
fi

