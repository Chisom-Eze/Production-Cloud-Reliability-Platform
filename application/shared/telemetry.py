import logging

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.botocore import BotocoreInstrumentor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.psycopg import PsycopgInstrumentor
from opentelemetry.sdk.resources import (
    DEPLOYMENT_ENVIRONMENT,
    Resource,
    SERVICE_NAME,
    SERVICE_VERSION,
)
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased

from application.shared.config import Settings

logger = logging.getLogger("application.telemetry")


def configure_tracing(settings: Settings, default_service_name: str) -> None:
    if not settings.otel_enabled:
        return
    try:
        if settings.otel_traces_sampler != "parentbased_traceidratio":
            logger.warning(
                "unsupported OpenTelemetry sampler configured; using parentbased_traceidratio",
                extra={
                    "service": default_service_name,
                    "sampler": settings.otel_traces_sampler,
                },
            )
        sampler = ParentBased(TraceIdRatioBased(settings.otel_traces_sampler_arg))
        resource = Resource.create(
            {
                SERVICE_NAME: settings.otel_service_name or default_service_name,
                DEPLOYMENT_ENVIRONMENT: settings.environment,
                SERVICE_VERSION: "0.1.0",
            }
        )
        provider = TracerProvider(resource=resource, sampler=sampler)
        provider.add_span_processor(
            BatchSpanProcessor(
                OTLPSpanExporter(endpoint=settings.otel_exporter_otlp_endpoint)
            )
        )
        trace.set_tracer_provider(provider)
        PsycopgInstrumentor().instrument()
        BotocoreInstrumentor().instrument()
    except Exception as exc:  # noqa: BLE001 - OTel must not block startup.
        logger.warning(
            "OpenTelemetry tracing setup failed",
            extra={"service": default_service_name, "error_type": type(exc).__name__},
        )


def instrument_fastapi(app) -> None:
    try:
        FastAPIInstrumentor.instrument_app(app)
    except Exception as exc:  # noqa: BLE001 - instrumentation must not block startup.
        logger.warning(
            "FastAPI tracing instrumentation failed",
            extra={"service": "api", "error_type": type(exc).__name__},
        )


def tracer(name: str):
    return trace.get_tracer(name)
