from datetime import datetime
from typing import Optional

import jwt
from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from api import models
from api import schemas
from api.database import get_db, get_read_db
from . import users as user_routes

security = HTTPBearer(auto_error=False)

router = APIRouter(prefix="/activity", tags=["Activity"])


def _get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_read_db),
) -> models.User:
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

    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Пользователь не найден")

    return user


def _detect_platform(user_agent: str | None, explicit: str | None) -> str:
    if explicit and explicit.strip():
        return explicit.strip().lower()

    if not user_agent:
        return "unknown"

    lowered = user_agent.lower()
    if "android" in lowered:
        return "android"
    if "iphone" in lowered or "ipad" in lowered or "ios" in lowered:
        return "ios"
    if "windows" in lowered:
        return "windows"
    if "mac os" in lowered or "macos" in lowered:
        return "macos"
    if "linux" in lowered:
        return "linux"
    if "webkit" in lowered or "chrome" in lowered or "safari" in lowered:
        return "web"
    return "unknown"


@router.post("/heartbeat", status_code=status.HTTP_204_NO_CONTENT)
def heartbeat(
    payload: schemas.UserActivityHeartbeat,
    request: Request,
    current_user: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
    x_client_platform: str | None = Header(default=None, convert_underscores=False),
):
    platform = _detect_platform(request.headers.get("user-agent"), payload.platform or x_client_platform)
    now = datetime.utcnow()

    existing = (
        db.query(models.UserSession)
        .filter(
            models.UserSession.user_id == current_user.id,
            models.UserSession.platform == platform,
        )
        .first()
    )

    if existing:
        existing.last_seen = now
    else:
        db.add(
            models.UserSession(
                user_id=current_user.id,
                platform=platform,
                started_at=now,
                last_seen=now,
            )
        )

    db.commit()

