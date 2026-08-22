from time import perf_counter

from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

HTTP_REQUESTS = Counter(
    "app_http_requests_total",
    "Total HTTP requests.",
    ["method", "path", "status_code"],
)
HTTP_DURATION = Histogram(
    "app_http_request_duration_seconds",
    "HTTP request duration in seconds.",
    ["method", "path"],
)
APP_ERRORS = Counter(
    "app_errors_total",
    "Application errors.",
    ["path", "error_type"],
)


class PrometheusMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        started = perf_counter()
        path = request.url.path
        try:
            response = await call_next(request)
            return response
        except Exception as exc:
            APP_ERRORS.labels(path=path, error_type=type(exc).__name__).inc()
            raise
        finally:
            status_code = locals().get("response").status_code if "response" in locals() else 500
            HTTP_REQUESTS.labels(
                method=request.method,
                path=path,
                status_code=str(status_code),
            ).inc()
            HTTP_DURATION.labels(method=request.method, path=path).observe(perf_counter() - started)


def metrics_response() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
