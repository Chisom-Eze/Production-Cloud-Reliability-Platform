import json
import logging
import sys
from contextvars import ContextVar
from datetime import UTC, datetime
from time import perf_counter
from uuid import uuid4

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

request_id_var: ContextVar[str | None] = ContextVar("request_id", default=None)
correlation_id_var: ContextVar[str | None] = ContextVar("correlation_id", default=None)


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(UTC).isoformat(),
            "level": record.levelname,
            "service": getattr(record, "service", "api"),
            "message": record.getMessage(),
            "request_id": request_id_var.get(),
            "correlation_id": correlation_id_var.get(),
        }

        for key in ("method", "path", "status_code", "latency_ms", "error", "job_id"):
            value = getattr(record, key, None)
            if value is not None:
                payload[key] = value

        if record.exc_info:
            payload["error"] = self.formatException(record.exc_info)

        return json.dumps(payload, separators=(",", ":"))


def configure_logging(level: str, service: str) -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level.upper())
    logging.LoggerAdapter(root, {"service": service})


class RequestContextMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, service_name: str = "api") -> None:
        super().__init__(app)
        self.service_name = service_name

    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("x-request-id") or str(uuid4())
        correlation_id = request.headers.get("x-correlation-id") or request_id
        request_token = request_id_var.set(request_id)
        correlation_token = correlation_id_var.set(correlation_id)
        started = perf_counter()

        try:
            response = await call_next(request)
            latency_ms = round((perf_counter() - started) * 1000, 2)
            logging.getLogger("application.api").info(
                "request completed",
                extra={
                    "service": self.service_name,
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "latency_ms": latency_ms,
                },
            )
            response.headers["x-request-id"] = request_id
            response.headers["x-correlation-id"] = correlation_id
            return response
        except Exception as exc:
            latency_ms = round((perf_counter() - started) * 1000, 2)
            logging.getLogger("application.api").exception(
                "request failed",
                extra={
                    "service": self.service_name,
                    "method": request.method,
                    "path": request.url.path,
                    "latency_ms": latency_ms,
                    "error": str(exc),
                },
            )
            raise
        finally:
            request_id_var.reset(request_token)
            correlation_id_var.reset(correlation_token)

