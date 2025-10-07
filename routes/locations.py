from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db
from .location_utils import ensure_location_for_user


router = APIRouter(prefix="/locations", tags=["Locations"])


@router.get("/{user_id}", response_model=List[schemas.WardrobeLocationResponse])
def list_locations(user_id: int, db: Session = Depends(get_db)):
    user_exists = db.query(models.User.id).filter(models.User.id == user_id).first()
    if not user_exists:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    return (
        db.query(models.WardrobeLocation)
        .filter(models.WardrobeLocation.user_id == user_id)
        .order_by(models.WardrobeLocation.created_at.asc())
        .all()
    )


@router.post("/{user_id}", response_model=schemas.WardrobeLocationResponse, status_code=201)
def create_location(
    user_id: int,
    payload: schemas.WardrobeLocationCreate,
    db: Session = Depends(get_db),
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Название локации не может быть пустым")

    location = models.WardrobeLocation(
        user_id=user_id,
        name=name,
        latitude=payload.latitude,
        longitude=payload.longitude,
    )
    db.add(location)
    db.commit()
    db.refresh(location)
    return location


@router.put("/{user_id}/{location_id}", response_model=schemas.WardrobeLocationResponse)
def update_location(
    user_id: int,
    location_id: int,
    payload: schemas.WardrobeLocationUpdate,
    db: Session = Depends(get_db),
):
    location = ensure_location_for_user(db, user_id, location_id)
    fields_set = set(getattr(payload, "__fields_set__", set())) or set(
        getattr(payload, "model_fields_set", set())
    )

    if payload.name is not None:
        new_name = payload.name.strip()
        if not new_name:
            raise HTTPException(status_code=400, detail="Название локации не может быть пустым")
        location.name = new_name

    if payload.latitude is not None:
        location.latitude = payload.latitude
    elif "latitude" in fields_set:
        location.latitude = None

    if payload.longitude is not None:
        location.longitude = payload.longitude
    elif "longitude" in fields_set:
        location.longitude = None

    db.commit()
    db.refresh(location)
    return location


@router.delete("/{user_id}/{location_id}")
def delete_location(user_id: int, location_id: int, db: Session = Depends(get_db)):
    location = ensure_location_for_user(db, user_id, location_id)

    db.delete(location)
    db.commit()
    return {"message": "Локация удалена"}
