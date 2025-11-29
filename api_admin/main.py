from __future__ import annotations

import logging
import time
import uuid

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from slowapi.errors import RateLimitExceeded

from api import models, settings
from api.cache import cache
from api.database import engine
from api.logging_config import configure_logging, reset_request_context, set_request_context
from api.observability import configure_observability
from api_admin.routes import admin


configure_logging()
logger = logging.getLogger(__name__)

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Garderobus Admin API")


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log every HTTP request with duration, status and correlation ids."""

    request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    trace_id = request.headers.get("X-Trace-Id")
    tokens = set_request_context(request_id=request_id, trace_id=trace_id)

    client_host = request.headers.get("X-Forwarded-For")
    if request.client and not client_host:
        client_host = request.client.host

    user_agent = request.headers.get("user-agent")
    start_time = time.perf_counter()

    try:
        response = await call_next(request)
    except Exception:
        duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
        logger.exception(
            "Unhandled application error",
            extra={
                "method": request.method,
                "path": request.url.path,
                "client": client_host,
                "user_agent": user_agent,
                "duration_ms": duration_ms,
                "request_id": request_id,
            },
        )
        reset_request_context(*tokens)
        raise

    duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
    level = logging.INFO
    if response.status_code >= 500:
        level = logging.ERROR
    elif response.status_code >= 400:
        level = logging.WARNING

    logger.log(
        level,
        "HTTP request completed",
        extra={
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": duration_ms,
            "client": client_host,
            "user_agent": user_agent,
            "request_id": request_id,
        },
    )

    response.headers["X-Request-ID"] = request_id
    reset_request_context(*tokens)
    return response


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(admin.router)

configure_observability(app)

logger.info(
    "Garderobus Admin API initialised",
    extra={"rate_limit": settings.API_RATE_LIMIT, "tracing": settings.TRACING_ENABLED},
)


@app.get("/")
def read_root() -> dict[str, str]:
    return {"message": "Garderobus Admin API is running!"}


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

