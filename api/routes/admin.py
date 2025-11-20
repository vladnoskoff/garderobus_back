from __future__ import annotations

from datetime import datetime, timedelta
from typing import List, Optional, Sequence

import jwt
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session
from sqlalchemy import or_
from sqlalchemy.sql import func

import models
import schemas
from database import get_db, get_read_db
from services import system_tools
from . import users as user_routes

security = HTTPBearer(auto_error=False)

router = APIRouter(prefix="/admin", tags=["Admin Panel"])


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


def _build_user_summaries(db: Session, users: Sequence[models.User]) -> List[schemas.AdminUserSummary]:
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

    location_counts = dict(
        db.query(models.WardrobeLocation.user_id, func.count(models.WardrobeLocation.id))
        .filter(models.WardrobeLocation.user_id.in_(user_ids))
        .group_by(models.WardrobeLocation.user_id)
        .all()
    )

    pending_metadata_counts = dict(
        db.query(models.Clothes.user_id, func.count(models.Clothes.id))
        .outerjoin(
            models.ClothesMetadata,
            models.ClothesMetadata.clothes_id == models.Clothes.id,
        )
        .filter(
            models.Clothes.user_id.in_(user_ids),
            or_(
                models.ClothesMetadata.clothes_id.is_(None),
                models.ClothesMetadata.data.is_(None),
            ),
        )
        .group_by(models.Clothes.user_id)
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
                locations_count=location_counts.get(user.id, 0),
                pending_metadata_items=pending_metadata_counts.get(user.id, 0),
            )
        )

    return summaries


def _build_location_details(db: Session, user_id: int) -> List[schemas.AdminUserLocationDetail]:
    locations = (
        db.query(models.WardrobeLocation)
        .filter(models.WardrobeLocation.user_id == user_id)
        .order_by(models.WardrobeLocation.created_at.asc())
        .all()
    )

    last_30_days = datetime.utcnow() - timedelta(days=30)

    clothes_by_location = dict(
        db.query(models.Clothes.location_id, func.count(models.Clothes.id))
        .filter(models.Clothes.user_id == user_id)
        .group_by(models.Clothes.location_id)
        .all()
    )

    new_clothes_by_location = dict(
        db.query(models.Clothes.location_id, func.count(models.Clothes.id))
        .filter(
            models.Clothes.user_id == user_id,
            models.Clothes.created_at >= last_30_days,
        )
        .group_by(models.Clothes.location_id)
        .all()
    )

    images_by_location = dict(
        db.query(models.Clothes.location_id, func.count(models.ClothesImage.id))
        .join(models.ClothesImage, models.ClothesImage.clothes_id == models.Clothes.id)
        .filter(models.Clothes.user_id == user_id)
        .group_by(models.Clothes.location_id)
        .all()
    )

    mannequins_by_location = dict(
        db.query(models.MannequinImage.location_id, func.count(models.MannequinImage.id))
        .filter(models.MannequinImage.user_id == user_id)
        .group_by(models.MannequinImage.location_id)
        .all()
    )

    wear_by_location = dict(
        db.query(models.Clothes.location_id, func.count(models.WearHistory.id))
        .join(models.WearHistory, models.WearHistory.clothing_id == models.Clothes.id)
        .filter(models.Clothes.user_id == user_id)
        .group_by(models.Clothes.location_id)
        .all()
    )

    pending_by_location = dict(
        db.query(models.Clothes.location_id, func.count(models.Clothes.id))
        .outerjoin(
            models.ClothesMetadata,
            models.ClothesMetadata.clothes_id == models.Clothes.id,
        )
        .filter(
            models.Clothes.user_id == user_id,
            or_(
                models.ClothesMetadata.clothes_id.is_(None),
                models.ClothesMetadata.data.is_(None),
            ),
        )
        .group_by(models.Clothes.location_id)
        .all()
    )

    details: List[schemas.AdminUserLocationDetail] = []

    for location in locations:
        details.append(
            schemas.AdminUserLocationDetail(
                id=location.id,
                name=location.name,
                created_at=location.created_at,
                total_clothes=clothes_by_location.get(location.id, 0),
                new_clothes_last_30_days=new_clothes_by_location.get(location.id, 0),
                total_clothes_images=images_by_location.get(location.id, 0),
                total_wear_events=wear_by_location.get(location.id, 0),
                mannequins_generated=mannequins_by_location.get(location.id, 0),
                pending_metadata_items=pending_by_location.get(location.id, 0),
            )
        )

    has_unassigned = any(
        mapping.get(None, 0) > 0
        for mapping in (
            clothes_by_location,
            new_clothes_by_location,
            images_by_location,
            wear_by_location,
            mannequins_by_location,
            pending_by_location,
        )
    )

    if has_unassigned:
        details.insert(
            0,
            schemas.AdminUserLocationDetail(
                id=None,
                name="Без локации",
                created_at=None,
                total_clothes=clothes_by_location.get(None, 0),
                new_clothes_last_30_days=new_clothes_by_location.get(None, 0),
                total_clothes_images=images_by_location.get(None, 0),
                total_wear_events=wear_by_location.get(None, 0),
                mannequins_generated=mannequins_by_location.get(None, 0),
                pending_metadata_items=pending_by_location.get(None, 0),
                is_virtual=True,
            ),
        )

    return details



@router.get("/system/status", response_model=schemas.AdminSystemStatus)
def get_system_status(
    _: models.User = Depends(_get_current_user),
) -> schemas.AdminSystemStatus:
    return system_tools.get_system_status()


@router.get("/system/events", response_model=schemas.AdminSystemEventList)
def get_system_events(
    level: str | None = Query(None, pattern=r"^(info|warning|error)$"),
    hours: int | None = Query(None, ge=1, le=24 * 30),
    limit: int = Query(50, ge=1, le=200),
    page: int = Query(1, ge=1),
    _: models.User = Depends(_get_current_user),
) -> schemas.AdminSystemEventList:
    return system_tools.get_system_events(level=level, hours=hours, limit=limit, page=page)


@router.get("/system/files", response_model=schemas.AdminManagedFileList)
def list_managed_files(
    _: models.User = Depends(_get_current_user),
) -> schemas.AdminManagedFileList:
    return schemas.AdminManagedFileList(files=system_tools.list_managed_files())


@router.get("/system/files/{relative_path:path}", response_model=schemas.AdminCodeFile)
def read_managed_file_endpoint(
    relative_path: str,
    _: models.User = Depends(_get_current_user),
) -> schemas.AdminCodeFile:
    return system_tools.read_managed_file(relative_path)


@router.put("/system/files/{relative_path:path}", response_model=schemas.AdminCodeFile)
def update_managed_file(
    relative_path: str,
    payload: schemas.AdminCodeUpdateRequest,
    current_user: models.User = Depends(_get_current_user),
) -> schemas.AdminCodeFile:
    return system_tools.write_managed_file(
        relative_path,
        payload.content,
        message=payload.message,
        actor=current_user,
    )


@router.post("/system/restart", response_model=schemas.AdminRestartResponse)
def restart_api_endpoint(
    current_user: models.User = Depends(_get_current_user),
) -> schemas.AdminRestartResponse:
    return system_tools.restart_api(requested_by=current_user)


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
    return _build_user_summaries(db, users)


@router.get("/users/{user_id}", response_model=schemas.AdminUserDetail)
def get_user_detail(
    user_id: int,
    _: models.User = Depends(_get_current_user),
    db: Session = Depends(get_read_db),
) -> schemas.AdminUserDetail:
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")

    summary = _build_user_summaries(db, [user])
    if not summary:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")

    locations = _build_location_details(db, user.id)

    return schemas.AdminUserDetail(
        **summary[0].model_dump(),
        theme_preference=user.theme_preference,
        language_preference=user.language_preference,
        gender=user.gender,
        has_pin=user.has_pin,
        locations=locations,
    )
