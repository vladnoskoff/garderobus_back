from typing import Optional, Tuple

from fastapi import HTTPException
from sqlalchemy.orm import Session

from api import models
from api import settings


def ensure_location_for_user(db: Session, user_id: int, location_id: int) -> models.WardrobeLocation:
    location = (
        db.query(models.WardrobeLocation)
        .filter(models.WardrobeLocation.id == location_id, models.WardrobeLocation.user_id == user_id)
        .first()
    )
    if not location:
        raise HTTPException(status_code=404, detail="Локация не найдена для пользователя")
    return location


def resolve_location_and_coordinates(
    db: Session,
    user: models.User,
    location_id: Optional[int],
) -> Tuple[Optional[models.WardrobeLocation], float, float]:
    """Возвращает выбранную локацию и координаты для пользователя."""

    if location_id is None:
        raw_location = user.location or settings.DEFAULT_USER_LOCATION
        if not raw_location:
            raise HTTPException(status_code=400, detail="Для пользователя не заданы координаты")
        try:
            lat, lon = map(float, raw_location.split(","))
        except Exception as exc:
            raise HTTPException(status_code=400, detail="Некорректный формат координат пользователя") from exc
        return None, lat, lon

    location = ensure_location_for_user(db, user.id, location_id)
    if location.latitude is None or location.longitude is None:
        raise HTTPException(
            status_code=400,
            detail="Для выбранной локации не заданы координаты",
        )

    return location, float(location.latitude), float(location.longitude)
