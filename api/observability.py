"""Utilities for wiring metrics, tracing and rate limiting."""
from __future__ import annotations

import logging
from typing import Optional

from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_fastapi_instrumentator import Instrumentator
from slowapi import Limiter
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address

import settings

logger = logging.getLogger(__name__)

_instrumentator: Optional[Instrumentator] = None
_tracer_provider: Optional[TracerProvider] = None


def setup_metrics(app: FastAPI) -> None:
    """Register Prometheus metrics exporters for the FastAPI app."""

    global _instrumentator
    if _instrumentator is not None:
        logger.debug("Prometheus instrumentator already configured")
        return

    _instrumentator = Instrumentator(should_group_status_codes=True, should_gzip=True)
    _instrumentator.instrument(app)
    logger.info("Prometheus metrics instrumentation enabled")


def setup_tracing(app: FastAPI) -> None:
    """Configure OpenTelemetry tracing with Jaeger exporter when enabled."""

    if not settings.TRACING_ENABLED:
        logger.info("Tracing disabled via configuration")
        return

    global _tracer_provider
    if _tracer_provider is not None:
        logger.debug("Tracer provider already configured")
        return

    service_name = settings.TRACING_SERVICE_NAME
    tracer_resource = Resource.create({"service.name": service_name})
    _tracer_provider = TracerProvider(resource=tracer_resource)

    jaeger_exporter = JaegerExporter(
        agent_host_name=settings.JAEGER_AGENT_HOST,
        agent_port=settings.JAEGER_AGENT_PORT,
    )

    span_processor = BatchSpanProcessor(jaeger_exporter)
    _tracer_provider.add_span_processor(span_processor)
    trace.set_tracer_provider(_tracer_provider)

    FastAPIInstrumentor.instrument_app(app)
    RequestsInstrumentor().instrument()

    logger.info(
        "Tracing enabled", extra={"service": service_name, "jaeger": f"{settings.JAEGER_AGENT_HOST}:{settings.JAEGER_AGENT_PORT}"}
    )


def setup_rate_limiter(app: FastAPI) -> Limiter:
    """Attach global rate limiting middleware to the app."""

    limiter = Limiter(
        key_func=get_remote_address,
        default_limits=[settings.API_RATE_LIMIT],
        headers_enabled=True,
    )
    app.state.limiter = limiter
    app.add_middleware(SlowAPIMiddleware)
    logger.info("API rate limiting enabled", extra={"limit": settings.API_RATE_LIMIT})
    return limiter


def configure_observability(app: FastAPI) -> None:
    """Entrypoint to configure metrics, tracing and rate limiting."""

    setup_metrics(app)
    setup_tracing(app)
    setup_rate_limiter(app)

