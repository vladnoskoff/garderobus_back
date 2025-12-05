from __future__ import annotations

import json
import os
from ipaddress import ip_address
from pathlib import Path
from typing import Iterable, Mapping, Optional, Tuple

import jwt
from fastapi import HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

import models
import settings
from database import db_session
from routes import users as user_routes

auth_scheme = HTTPBearer(auto_error=False)


_BLOCKLIST_CACHE: tuple[float, set[str]] = (0.0, set())


_PUBLIC_PATHS: tuple[str, ...] = (
    "/",  # root sanity check
    "/311",  # legacy uptime alias
    "/docs",
    "/openapi.json",
    "/redoc",
    "/healthz",
    "/metrics",
)


_PUBLIC_PREFIXES: tuple[str, ...] = (
    "/clothes_images/",
    "/mannequins/",
)


_PUBLIC_ROUTE_PREFIXES: tuple[str, ...] = (
    "/users/register",
    "/users/login",
)

# Read-only routes that can be fetched without auth (used by public widgets/cron jobs).
_PUBLIC_GET_PREFIXES: tuple[str, ...] = (
    "/users/",
    "/locations/",
    "/clothes/user",
    "/weather/user",
    "/ai/mannequin/",
    "/ai/tasks/",
)


def _blocklist_path() -> Path:
    raw = os.getenv("IP_BLOCKLIST_PATH")
    return Path(raw) if raw else settings.IP_BLOCKLIST_PATH


def _load_ip_blocklist() -> tuple[float, set[str]]:
    path = _blocklist_path()
    try:
        stats = path.stat()
    except OSError:
        return (0.0, set())

    cached_mtime, cached_items = _BLOCKLIST_CACHE
    if cached_mtime and cached_mtime == stats.st_mtime:
        return (cached_mtime, cached_items)

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return (0.0, set())

    entries: set[str] = set()
    for raw in data if isinstance(data, list) else []:
        if not isinstance(raw, str):
            continue
        try:
            entries.add(str(ip_address(raw.strip())))
        except ValueError:
            continue

    mtime = stats.st_mtime if entries else 0.0
    return (mtime, entries)


def is_ip_blocked(client_ip: Optional[str]) -> bool:
    if not client_ip:
        return False

    try:
        normalized = str(ip_address(client_ip.split(",")[0].strip()))
    except ValueError:
        return False

    global _BLOCKLIST_CACHE
    cached_mtime, cached_items = _BLOCKLIST_CACHE
    mtime, items = _load_ip_blocklist()
    if mtime != cached_mtime or cached_items is None:
        _BLOCKLIST_CACHE = (mtime, items)
        cached_items = items

    return normalized in cached_items


def detect_client_origin(
    user_agent: Optional[str],
    headers: Optional[Mapping[str, str]] = None,
) -> tuple[str, str]:
    ua = (user_agent or "").lower()
    header_hint = None
    header_value = None
    if headers:
        header_value = headers.get("x-client-origin") or headers.get("x-client-platform")
        header_hint = (header_value or "").lower()

    def hint_from_value(raw: str) -> tuple[str, str]:
        lowered = raw.lower()
        if "flutter" in lowered or "dart" in lowered:
            return ("flutter_app", raw)
        if "okhttp" in lowered:
            return ("flutter_app", raw)
        if "postman" in lowered or "insomnia" in lowered:
            return ("api_client", raw)
        if "curl" in lowered or "httpie" in lowered:
            return ("api_client", raw)
        if any(browser in lowered for browser in ("mozilla", "chrome", "safari", "firefox", "edge")):
            return ("browser", raw)
        return ("unknown", raw)

    if header_hint:
        origin, evidence = hint_from_value(header_hint)
        if origin != "unknown":
            return (origin, evidence)

    if ua:
        origin, evidence = hint_from_value(ua)
        if origin != "unknown":
            return (origin, evidence)

    if header_value:
        return ("unknown", header_value)
    if user_agent:
        return ("unknown", user_agent)
    return ("unknown", "")


def is_public_path(
    path: str, *, method: Optional[str] = None, extra_public: Optional[Iterable[str]] = None
) -> bool:
    """Return True when path should bypass auth enforcement."""

    normalized = path.rstrip("/") or "/"

    if normalized in _PUBLIC_PATHS or any(normalized.startswith(prefix) for prefix in _PUBLIC_PREFIXES):
        return True

    if extra_public and any(normalized.startswith(prefix.rstrip("/")) for prefix in extra_public):
        return True

    if method and method.upper() == "GET" and any(
        normalized.startswith(prefix) for prefix in _PUBLIC_GET_PREFIXES
    ):
        return True

    return any(normalized.startswith(prefix) for prefix in _PUBLIC_ROUTE_PREFIXES)


def extract_bearer_token(
    *, headers: Mapping[str, str], query_params: Mapping[str, str], cookies: Optional[Mapping[str, str]]
) -> Optional[str]:
    """Return a bearer token from common locations without enforcing scheme casing."""

    # Standard Authorization header first
    auth_header = headers.get("Authorization") or headers.get("authorization")
    if auth_header:
        parts = auth_header.split()
        if len(parts) == 2:
            return parts[1]
        if len(parts) == 1:
            return parts[0]

    # Alternate query parameters used by some clients
    token = query_params.get("access_token") or query_params.get("token")
    if token:
        return token

    # Cookie-based fallbacks
    if cookies:
        cookie_token = cookies.get("access_token")
        if cookie_token:
            return cookie_token

    return None


def resolve_token_identity(token: Optional[str]) -> Tuple[Optional[str], Optional[int]]:
    """Return user identity (email, id) from a bearer token when possible.

    The lookup is best-effort: malformed tokens or missing users simply return
    ``(None, None)`` so callers can safely log the absence without raising.
    """

    if not token:
        return (None, None)

    try:
        payload = jwt.decode(token, user_routes.SECRET_KEY, algorithms=[user_routes.ALGORITHM])
    except jwt.PyJWTError:
        return (None, None)

    email = payload.get("sub") or payload.get("email")
    user_id = payload.get("user_id")

    if user_id is not None:
        try:
            return (email, int(user_id))
        except (TypeError, ValueError):
            return (email, None)

    if not email:
        return (None, None)

    try:
        with db_session(read_only=True) as db:
            user = db.query(models.User.id).filter(models.User.email == email).first()
            return (email, user.id if user else None)
    except Exception:
        # Avoid breaking request logging when the database is unavailable.
        return (email, None)


def authenticate(credentials: Optional[HTTPAuthorizationCredentials]) -> models.User:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Требуется авторизация")

    token = credentials.credentials
    try:
        payload = jwt.decode(token, user_routes.SECRET_KEY, algorithms=[user_routes.ALGORITHM])
    except jwt.PyJWTError as exc:  # pragma: no cover - defensive branch
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Неверный токен") from exc

    email = payload.get("sub")
    if not email:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Неверный токен")

    with db_session(read_only=True) as db:
        user = db.query(models.User).filter(models.User.email == email).first()

    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Пользователь не найден")

    return user