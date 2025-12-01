from __future__ import annotations

from typing import Iterable, Optional

import jwt
from fastapi import HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

import models
from database import db_session
from routes import users as user_routes

auth_scheme = HTTPBearer(auto_error=False)


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


def is_public_path(path: str, extra_public: Optional[Iterable[str]] = None) -> bool:
    """Return True when path should bypass auth enforcement."""

    if path in _PUBLIC_PATHS or any(path.startswith(prefix) for prefix in _PUBLIC_PREFIXES):
        return True

    if extra_public and any(path.startswith(prefix) for prefix in extra_public):
        return True

    return any(path.startswith(prefix) for prefix in _PUBLIC_ROUTE_PREFIXES)


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
