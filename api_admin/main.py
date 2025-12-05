from __future__ import annotations

import logging
import time
import uuid
from datetime import datetime, timezone

from fastapi import FastAPI, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from slowapi.errors import RateLimitExceeded

import models
import settings
from cache import cache
from database import engine
from logging_config import configure_logging, reset_request_context, set_request_context
from observability import configure_observability
from api_admin.routes import admin, notifications
from security import (
    authenticate,
    auth_scheme,
    detect_client_origin,
    extract_bearer_token,
    resolve_token_identity,
    is_ip_blocked,
    is_public_path,
)


configure_logging()
logger = logging.getLogger(__name__)

_START_TIME = time.time()


def _humanize_duration(seconds: float) -> str:
    seconds = max(0, int(seconds))
    days, remainder = divmod(seconds, 86400)
    hours, remainder = divmod(remainder, 3600)
    minutes, seconds = divmod(remainder, 60)

    parts: list[str] = []
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

app = FastAPI(
    title="Garderobus Admin API",
    docs_url="/admin/docs",
    redoc_url="/admin/redoc",
    openapi_url="/admin/openapi.json",
)


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
    client_origin, origin_hint = detect_client_origin(user_agent, headers=request.headers)
    start_time = time.perf_counter()
    token = extract_bearer_token(
        headers=request.headers, query_params=request.query_params, cookies=request.cookies
    )
    user_email, user_id = resolve_token_identity(token)

    if is_ip_blocked(client_host):
        logger.warning(
            "Blocked request due to IP blocklist",
            extra={
                "method": request.method,
                "path": request.url.path,
                "client": client_host,
                "user_agent": user_agent,
                "client_origin": client_origin,
                "client_origin_hint": origin_hint,
                "request_id": request_id,
                "token": token or "-",
                "user_email": user_email or "-",
                "user_id": user_id or "-",
            },
        )
        reset_request_context(*tokens)
        response = JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={"detail": "Доступ с этого IP заблокирован"},
        )
        response.headers["X-Request-ID"] = request_id
        return response

    try:
        response = await call_next(request)
    except Exception:
        duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
        payload = {
            "method": request.method,
            "path": request.url.path,
            "client": client_host,
            "user_agent": user_agent,
            "duration_ms": duration_ms,
            "request_id": request_id,
            "token": token or "-",
            "user_email": user_email or "-",
            "user_id": user_id or "-",
        }

        if request.url.path.rstrip("/") == "/healthz":
            logger.warning("Health probe failed", extra=payload, exc_info=True)
            reset_request_context(*tokens)
            error_response = JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={"detail": "Health probe failed"},
            )
            error_response.headers["X-Request-ID"] = request_id
            return error_response

        logger.exception("Unhandled application error", extra=payload)
        reset_request_context(*tokens)
        error_response = JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={"detail": "Внутренняя ошибка сервера"},
        )
        error_response.headers["X-Request-ID"] = request_id
        return error_response

    duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
    level = logging.INFO
    if response.status_code >= 500:
        level = logging.ERROR
    elif response.status_code >= 400:
        level = logging.WARNING
    elif not token:
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
            "client_origin": client_origin,
            "client_origin_hint": origin_hint,
            "request_id": request_id,
            "token": token or "-",
            "user_email": user_email or "-",
            "user_id": user_id or "-",
        },
    )

    response.headers["X-Request-ID"] = request_id
    reset_request_context(*tokens)
    return response


@app.middleware("http")
async def enforce_authentication(request: Request, call_next):
    extra_public = ("/admin/login", "/admin/docs", "/admin/openapi.json", "/admin/redoc")

    # Allow CORS preflight checks to pass without auth to avoid blocking browsers
    if request.method == "OPTIONS":
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    if is_public_path(request.url.path, method=request.method, extra_public=extra_public):
        return await call_next(request)

    credentials = await auth_scheme(request)
    token = extract_bearer_token(
        headers=request.headers, query_params=request.query_params, cookies=request.cookies
    ) or (credentials.credentials if credentials else None)

    if token and credentials is None:
        credentials = HTTPAuthorizationCredentials(scheme="bearer", credentials=token)
    try:
        authenticate(credentials)
    except Exception as exc:
        status_code = getattr(exc, "status_code", status.HTTP_401_UNAUTHORIZED)
        detail = getattr(exc, "detail", "Требуется авторизация")
        response = JSONResponse(status_code=status_code, content={"detail": detail})
        response.headers["X-Request-ID"] = request.headers.get("X-Request-ID", "")
        return response

    return await call_next(request)


allowed_origins = settings.CORS_ALLOWED_ORIGINS or ["*"]
allow_all = "*" in allowed_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=[] if allow_all else allowed_origins,
    allow_origin_regex=".*" if allow_all else None,
    allow_credentials=not allow_all,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(admin.router)
app.include_router(notifications.router)

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
def healthcheck() -> dict[str, object]:
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