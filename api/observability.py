"""Utilities for wiring metrics, tracing and rate limiting."""
from __future__ import annotations

import inspect
import logging
from typing import Callable, Optional

import jwt
from fastapi import FastAPI, HTTPException, Request
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_client import Counter
from prometheus_fastapi_instrumentator import Instrumentator
from slowapi import Limiter
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address

import settings

logger = logging.getLogger(__name__)

_instrumentator: Optional[Instrumentator] = None
_tracer_provider: Optional[TracerProvider] = None
_limiter: Limiter = Limiter(key_func=get_remote_address, headers_enabled=True)

_auth_failures = Counter(
    "auth_failures_total",
    "Total authentication failures",
    labelnames=("reason",),
)
_auth_lockouts = Counter(
    "auth_lockouts_total",
    "Total authentication lockouts triggered",
    labelnames=("dimension",),
)


def get_rate_limiter() -> Limiter:
    return _limiter


def record_auth_failure(reason: str) -> None:
    _auth_failures.labels(reason=reason).inc()


def record_auth_lockout(dimension: str) -> None:
    _auth_lockouts.labels(dimension=dimension).inc()


def _user_or_ip_key(request: Request) -> str:
    auth_header = request.headers.get("authorization")
    if auth_header and auth_header.lower().startswith("bearer "):
        token = auth_header.split(" ", 1)[1]
        try:
            payload = jwt.decode(
                token,
                settings.JWT_SECRET_KEY,
                algorithms=[settings.JWT_ALGORITHM],
                options={"verify_exp": False},
            )
            user_id = payload.get("sub")
            if user_id is not None:
                return f"user:{user_id}"
        except jwt.PyJWTError:
            logger.debug("Unable to parse bearer token for rate limit key")
    ip_address = get_remote_address(request) or "unknown"
    return f"ip:{ip_address}"


def setup_metrics(app: FastAPI) -> None:
    """Register Prometheus metrics exporters for the FastAPI app."""

    global _instrumentator
    if _instrumentator is not None:
        logger.debug("Prometheus instrumentator already configured")
        return

    instrumentator_kwargs = {"should_group_status_codes": True}
    instrumentator_signature = inspect.signature(Instrumentator)
    if "should_gzip" in instrumentator_signature.parameters:
        instrumentator_kwargs["should_gzip"] = True
    else:
        logger.debug(
            "prometheus-fastapi-instrumentator lacks should_gzip option; skipping"
        )

    _instrumentator = Instrumentator(**instrumentator_kwargs)
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

    if settings.OTEL_EXPORTER_OTLP_ENDPOINT:
        exporter = OTLPSpanExporter(
            endpoint=settings.OTEL_EXPORTER_OTLP_ENDPOINT,
            headers=_parse_otlp_headers(settings.OTEL_EXPORTER_OTLP_HEADERS),
        )
        exporter_name = "otlp"
    else:
        exporter = JaegerExporter(
            agent_host_name=settings.JAEGER_AGENT_HOST,
            agent_port=settings.JAEGER_AGENT_PORT,
        )
        exporter_name = "jaeger"

    span_processor = BatchSpanProcessor(exporter)
    _tracer_provider.add_span_processor(span_processor)
    trace.set_tracer_provider(_tracer_provider)

    FastAPIInstrumentor.instrument_app(app)
    RequestsInstrumentor().instrument()

    logger.info(
        "Tracing enabled",
        extra={
            "service": service_name,
            "exporter": exporter_name,
            "jaeger": f"{settings.JAEGER_AGENT_HOST}:{settings.JAEGER_AGENT_PORT}",
            "otlp_endpoint": settings.OTEL_EXPORTER_OTLP_ENDPOINT,
        },
    )


def _parse_otlp_headers(raw_headers: Optional[str]) -> dict[str, str]:
    if not raw_headers:
        return {}
    header_pairs = [segment.strip() for segment in raw_headers.split(",") if segment.strip()]
    parsed_headers = {}
    for pair in header_pairs:
        if ":" not in pair:
            continue
        key, value = pair.split(":", 1)
        parsed_headers[key.strip()] = value.strip()
    return parsed_headers


def setup_rate_limiter(app: FastAPI) -> Limiter:
    """Attach global rate limiting middleware to the app."""

    global _limiter
    _limiter.default_limits = [settings.API_RATE_LIMIT]
    _limiter.key_func = _user_or_ip_key
    app.state.limiter = _limiter
    app.add_middleware(SlowAPIMiddleware)
    logger.info("API rate limiting enabled", extra={"limit": settings.API_RATE_LIMIT})
    return _limiter


def configure_observability(app: FastAPI) -> None:
    """Entrypoint to configure metrics, tracing and rate limiting."""

    setup_metrics(app)
    setup_tracing(app)
    setup_rate_limiter(app)

