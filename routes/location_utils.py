from fastapi import HTTPException
from sqlalchemy.orm import Session

import models


def ensure_location_for_user(db: Session, user_id: int, location_id: int) -> models.WardrobeLocation:
    location = (
        db.query(models.WardrobeLocation)
        .filter(models.WardrobeLocation.id == location_id, models.WardrobeLocation.user_id == user_id)
        .first()
    )
    if not location:
        raise HTTPException(status_code=404, detail="Локация не найдена для пользователя")
    return location
