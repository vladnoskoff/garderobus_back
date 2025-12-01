from __future__ import annotations

import logging
import time
import uuid
from datetime import datetime, timezone

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from slowapi.errors import RateLimitExceeded

import models
import settings
from cache import cache
from database import engine
from logging_config import configure_logging, reset_request_context, set_request_context
from observability import configure_observability
from routes import (
    activity,
    ai_recommendation,
    clothes,
    esp_display,
    locations,
    outfits,
    testgpt,
    users,
    wardrobe_analytics,
    weather,
)
from security import authenticate, auth_scheme, is_public_path
from static_files import CDNStaticFiles

configure_logging()
logger = logging.getLogger(__name__)

_START_TIME = time.time()


def _humanize_duration(seconds: float) -> str:
    seconds = max(0, int(seconds))
    days, remainder = divmod(seconds, 86400)
    hours, remainder = divmod(remainder, 3600)
    minutes, seconds = divmod(remainder, 60)

    parts = []
    if days:
        parts.append(f"{days} д")
    if hours:
        parts.append(f"{hours} ч")
    if minutes:
        parts.append(f"{minutes} мин")
    if seconds or not parts:
        parts.append(f"{seconds} с")

    return " ".join(parts)

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Smart Closet API", swagger_ui_parameters={"persistAuthorization": True})


def _custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema

    schema = get_openapi(
        title=app.title,
        version="1.0.0",
        description="Smart Closet public API",
        routes=app.routes,
    )

    components = schema.setdefault("components", {})
    security_schemes = components.setdefault("securitySchemes", {})
    security_schemes.setdefault("HTTPBearer", {"type": "http", "scheme": "bearer"})

    app.openapi_schema = schema
    return app.openapi_schema


app.openapi = _custom_openapi


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


@app.middleware("http")
async def enforce_authentication(request: Request, call_next):
    if is_public_path(request.url.path):
        return await call_next(request)

    credentials = await auth_scheme(request)
    authenticate(credentials)

    return await call_next(request)

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

app.include_router(activity.router)
app.include_router(users.router)
app.include_router(clothes.router)
app.include_router(outfits.router)
app.include_router(weather.router)
app.include_router(ai_recommendation.router)
app.include_router(wardrobe_analytics.router)
app.include_router(esp_display.router)
app.include_router(testgpt.router)
app.include_router(locations.router)

configure_observability(app)

logger.info(
    "Smart Closet API initialised",
    extra={"rate_limit": settings.API_RATE_LIMIT, "tracing": settings.TRACING_ENABLED},
)


@app.get("/")
def read_root() -> dict[str, str]:
    return {"message": "Smart Closet API is running!"}
@app.get("/311")
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

    uptime_seconds = time.time() - _START_TIME
    started_at = datetime.fromtimestamp(_START_TIME, tz=timezone.utc)

    return {
        "status": "ok",
        "uptime_seconds": uptime_seconds,
        "uptime_human": _humanize_duration(uptime_seconds),
        "started_at": started_at.isoformat(),
    }


@app.on_event("shutdown")
def shutdown_event() -> None:
    """Dispose of the SQLAlchemy engine so connections close gracefully."""

    engine.dispose()
    cache.close()
