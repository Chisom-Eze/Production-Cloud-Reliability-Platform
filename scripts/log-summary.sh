#!/usr/bin/env sh
set -eu

usage() {
  echo "usage: $0 SERVICE [LINES]" >&2
  echo "example: $0 api 100" >&2
  echo "services: api, nginx, worker, postgres" >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
  exit 2
fi

SERVICE="$1"
LINES="${2:-100}"

case "$SERVICE" in
  api|nginx|worker|postgres) ;;
  *)
    echo "unknown service: $SERVICE" >&2
    usage
    exit 2
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 2
fi

docker compose logs --tail "$LINES" "$SERVICE" \
  | sed 's/\r$//' \
  | awk '
      /status_code/ { status_lines++ }
      /"level":"ERROR"|error|failed|upstream/ { error_lines++ }
      { total++ }
      END {
        print "service=" service
        print "lines=" total+0
        print "status_lines=" status_lines+0
        print "error_like_lines=" error_lines+0
      }
    ' service="$SERVICE"

