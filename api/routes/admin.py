from __future__ import annotations

from datetime import datetime, timedelta
from typing import List

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session
from sqlalchemy.sql import func

import models
import schemas
from database import get_db, get_read_db
from . import users as user_routes

security = HTTPBearer(auto_error=False)

router = APIRouter(prefix="/admin", tags=["Admin Panel"])


def _get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
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


@router.post("/login")
def admin_login(credentials: schemas.UserLogin, db: Session = Depends(get_db)):
    """Делегируем авторизацию стандартному пользовательскому логину."""

    return user_routes.login(credentials, db)  # type: ignore[arg-type]


@router.post("/users", response_model=schemas.UserResponse)
def create_user(
    payload: schemas.UserCreate,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Создание пользователя с использованием бизнес-логики пользовательского модуля."""

    return user_routes.register(payload, db)  # type: ignore[arg-type]


@router.delete("/users/{user_id}")
def remove_user(
    user_id: int,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    return user_routes.delete_user(user_id, db)


@router.get("/users/summary", response_model=List[schemas.AdminUserSummary])
def get_users_summary(
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_read_db),
) -> List[schemas.AdminUserSummary]:
    users = db.query(models.User).order_by(models.User.id).all()
    if not users:
        return []

    user_ids = [user.id for user in users]

    clothes_counts = dict(
        db.query(models.Clothes.user_id, func.count(models.Clothes.id))
        .filter(models.Clothes.user_id.in_(user_ids))
        .group_by(models.Clothes.user_id)
        .all()
    )

    clothes_images_counts = dict(
        db.query(models.Clothes.user_id, func.count(models.ClothesImage.id))
        .join(models.Clothes, models.Clothes.id == models.ClothesImage.clothes_id)
        .filter(models.Clothes.user_id.in_(user_ids))
        .group_by(models.Clothes.user_id)
        .all()
    )

    mannequin_counts = dict(
        db.query(models.MannequinImage.user_id, func.count(models.MannequinImage.id))
        .filter(models.MannequinImage.user_id.in_(user_ids))
        .group_by(models.MannequinImage.user_id)
        .all()
    )

    outfit_counts = dict(
        db.query(models.Outfit.user_id, func.count(models.Outfit.id))
        .filter(models.Outfit.user_id.in_(user_ids))
        .group_by(models.Outfit.user_id)
        .all()
    )

    wear_counts = dict(
        db.query(models.WearHistory.user_id, func.count(models.WearHistory.id))
        .filter(models.WearHistory.user_id.in_(user_ids))
        .group_by(models.WearHistory.user_id)
        .all()
    )

    now = datetime.utcnow()
    last_30_days = now - timedelta(days=30)

    recent_wear_counts = dict(
        db.query(models.WearHistory.user_id, func.count(models.WearHistory.id))
        .filter(
            models.WearHistory.user_id.in_(user_ids),
            models.WearHistory.worn_at >= last_30_days,
        )
        .group_by(models.WearHistory.user_id)
        .all()
    )

    recent_clothes_counts = dict(
        db.query(models.Clothes.user_id, func.count(models.Clothes.id))
        .filter(
            models.Clothes.user_id.in_(user_ids),
            models.Clothes.created_at >= last_30_days,
        )
        .group_by(models.Clothes.user_id)
        .all()
    )

    last_wear_dates = dict(
        db.query(models.WearHistory.user_id, func.max(models.WearHistory.worn_at))
        .filter(models.WearHistory.user_id.in_(user_ids))
        .group_by(models.WearHistory.user_id)
        .all()
    )

    last_mannequin_dates = dict(
        db.query(models.MannequinImage.user_id, func.max(models.MannequinImage.created_at))
        .filter(models.MannequinImage.user_id.in_(user_ids))
        .group_by(models.MannequinImage.user_id)
        .all()
    )

    summaries: List[schemas.AdminUserSummary] = []

    for user in users:
        top_worn_rows = (
            db.query(
                models.Clothes.id,
                models.Clothes.name,
                func.count(models.WearHistory.id).label("usage_count"),
            )
            .join(models.WearHistory, models.WearHistory.clothing_id == models.Clothes.id)
            .filter(models.WearHistory.user_id == user.id)
            .group_by(models.Clothes.id)
            .order_by(func.count(models.WearHistory.id).desc())
            .limit(5)
            .all()
        )

        top_worn_items = [
            schemas.AdminUserUsageItem(
                clothing_id=row[0],
                name=row[1],
                usage_count=row[2],
            )
            for row in top_worn_rows
        ]

        summaries.append(
            schemas.AdminUserSummary(
                id=user.id,
                name=user.name,
                email=user.email,
                phone=user.phone,
                total_clothes=clothes_counts.get(user.id, 0),
                total_clothes_images=clothes_images_counts.get(user.id, 0),
                total_mannequins=mannequin_counts.get(user.id, 0),
                total_outfits=outfit_counts.get(user.id, 0),
                total_wear_events=wear_counts.get(user.id, 0),
                wear_events_last_30_days=recent_wear_counts.get(user.id, 0),
                new_clothes_last_30_days=recent_clothes_counts.get(user.id, 0),
                last_wear_at=last_wear_dates.get(user.id),
                last_mannequin_at=last_mannequin_dates.get(user.id),
                top_worn_items=top_worn_items,
            )
        )

    return summaries
