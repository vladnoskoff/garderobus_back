from __future__ import annotations

import logging
import uuid

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from slowapi.errors import RateLimitExceeded

from opentelemetry import trace

import models
import settings
from cache import cache
from database import engine
from logging_config import configure_logging, reset_request_context, set_request_context
from observability import configure_observability
from profiling import setup_profiling
from routes import build_versioned_router
from static_files import CDNStaticFiles

configure_logging()
logger = logging.getLogger(__name__)

models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Smart Closet API",
    version="1.0.0",
    description="OpenAPI contract for the Smart Closet backend service.",
)


@app.middleware("http")
async def enrich_request_context(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID") or uuid.uuid4().hex
    trace_id = request.headers.get("X-Trace-Id")
    tokens = set_request_context(request_id=request_id, trace_id=trace_id)
    request.state.request_id = request_id

    try:
        response = await call_next(request)
        current_span = trace.get_current_span()
        span_context = current_span.get_span_context()
        if span_context and span_context.is_valid:
            trace_id = format(span_context.trace_id, "032x")
        response.headers["X-Request-ID"] = request_id
        if trace_id:
            response.headers["X-Trace-Id"] = trace_id
        return response
    finally:
        reset_request_context(*tokens)

# Разрешаем CORS для доверенных источников
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount(
    "/clothes_images",
    CDNStaticFiles(
        directory=str(settings.CLOTHES_IMAGE_DIR),
        cache_control=settings.STATIC_CACHE_CONTROL,
        cdn_cache_control=settings.CDN_CACHE_CONTROL,
        enable_etag=settings.STATIC_ENABLE_ETAG,
    ),
    name="clothes_images",
)
app.mount(
    "/mannequins",
    CDNStaticFiles(
        directory=str(settings.MANNEQUIN_IMAGE_DIR),
        cache_control=settings.STATIC_CACHE_CONTROL,
        cdn_cache_control=settings.CDN_CACHE_CONTROL,
        enable_etag=settings.STATIC_ENABLE_ETAG,
    ),
    name="mannequins",
)

app.include_router(build_versioned_router("/v1"))
app.include_router(build_versioned_router("/v2"))
app.include_router(build_versioned_router(deprecated=True))

configure_observability(app)
setup_profiling(app)

logger.info(
    "Smart Closet API initialised",
    extra={"rate_limit": settings.API_RATE_LIMIT, "tracing": settings.TRACING_ENABLED},
)


@app.get("/")
def read_root() -> dict[str, str]:
    return {"message": "Smart Closet API is running!"}


@app.get("/metrics", tags=["monitoring"], summary="Prometheus metrics endpoint")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.exception_handler(RateLimitExceeded)
def rate_limit_handler(_: Request, exc: RateLimitExceeded) -> JSONResponse:
    retry_after = getattr(exc, "retry_after", 1)
    headers = {"Retry-After": str(retry_after)} if retry_after is not None else {}
    return JSONResponse(
        status_code=429,
        content={"detail": "Rate limit exceeded", "retry_after": retry_after},
        headers=headers,
    )


@app.get("/healthz", tags=["health"], summary="Service health probe")
def healthcheck() -> dict[str, str]:
    """Simple endpoint used by load balancers and orchestrators."""

    return {"status": "ok"}


@app.on_event("shutdown")
def shutdown_event() -> None:
    """Dispose of the SQLAlchemy engine so connections close gracefully."""

    engine.dispose()
    cache.close()
