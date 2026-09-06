from time import perf_counter

from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
    start_http_server,
)
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

HTTP_REQUESTS = Counter(
    "app_http_requests_total",
    "Total HTTP requests.",
    ["method", "route", "status_class"],
)
HTTP_DURATION = Histogram(
    "app_http_request_duration_seconds",
    "HTTP request duration in seconds.",
    ["method", "route"],
)
HTTP_IN_FLIGHT = Gauge(
    "app_http_requests_in_flight",
    "In-flight HTTP requests.",
    ["method", "route"],
)
APP_ERRORS = Counter(
    "app_errors_total",
    "Application errors.",
    ["route", "error_type"],
)
WORKER_OUTBOX_DISPATCH = Counter(
    "worker_outbox_dispatch_total",
    "Worker outbox dispatch attempts.",
    ["result"],
)
WORKER_JOBS_PROCESSED = Counter(
    "worker_jobs_processed_total",
    "Worker job processing results.",
    ["job_type", "result"],
)
WORKER_JOB_DURATION = Histogram(
    "worker_job_processing_duration_seconds",
    "Worker job processing duration in seconds.",
    ["job_type", "result"],
)
WORKER_DUPLICATE_JOBS = Counter(
    "worker_duplicate_jobs_total",
    "Duplicate jobs ignored by the worker.",
    ["result"],
)
WORKER_JOB_CLAIMS = Counter(
    "worker_job_claims_total",
    "Worker job claim attempts.",
    ["result"],
)
WORKER_OUTBOX_RECLAIMS = Counter(
    "worker_outbox_reclaims_total",
    "Worker outbox claim attempts.",
    ["result"],
)
WORKER_VISIBILITY_HEARTBEAT_FAILURES = Counter(
    "worker_visibility_heartbeat_failures_total",
    "SQS visibility heartbeat failures.",
    ["operation"],
)


class PrometheusMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        started = perf_counter()
        in_flight_route = "unmatched"
        HTTP_IN_FLIGHT.labels(method=request.method, route=in_flight_route).inc()
        try:
            response = await call_next(request)
            return response
        except Exception as exc:  # noqa: BLE001 - record metrics, then re-raise.
            route = _route_template(request)
            APP_ERRORS.labels(route=route, error_type=type(exc).__name__).inc()
            raise
        finally:
            route = _route_template(request)
            status_code = (
                locals().get("response").status_code if "response" in locals() else 500
            )
            status_class = f"{status_code // 100}xx"
            HTTP_REQUESTS.labels(
                method=request.method,
                route=route,
                status_class=status_class,
            ).inc()
            HTTP_DURATION.labels(method=request.method, route=route).observe(
                perf_counter() - started
            )
            HTTP_IN_FLIGHT.labels(method=request.method, route=in_flight_route).dec()


def metrics_response() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


def _route_template(request) -> str:
    route = request.scope.get("route")
    if route is not None and getattr(route, "path", None):
        return route.path
    return "unmatched"


def start_worker_metrics_server(host: str, port: int) -> bool:
    try:
        start_http_server(port, addr=host)
        return True
    except Exception:  # noqa: BLE001 - metrics startup is best-effort telemetry.
        return False
