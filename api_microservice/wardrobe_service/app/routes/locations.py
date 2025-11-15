from typing import List

from fastapi import APIRouter, Depends, HTTPException
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session

from api_microservice.common import models, schemas, settings
from api_microservice.common.cache import (
    cache,
    invalidate_locations_for_user,
    invalidate_outfit_history_for_user,
)

from ..database import get_db
from .location_utils import ensure_location_for_user


router = APIRouter(prefix="/locations", tags=["Locations"])


@router.get("/{user_id}", response_model=List[schemas.WardrobeLocationResponse])
def list_locations(user_id: int, db: Session = Depends(get_db)):
    user_exists = db.query(models.User.id).filter(models.User.id == user_id).first()
    if not user_exists:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    cache_key = cache.make_key("locations", user_id)
    cached = cache.get_json(cache_key, resource="locations")
    if cached is not None:
        return cached

    locations = (
        db.query(models.WardrobeLocation)
        .filter(models.WardrobeLocation.user_id == user_id)
        .order_by(models.WardrobeLocation.created_at.asc())
        .all()
    )

    cache.set_json(
        cache_key,
        jsonable_encoder(locations),
        ttl=settings.CACHE_TTL_LOCATIONS,
        resource="locations",
    )

    return locations


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
    invalidate_locations_for_user(user_id)
    invalidate_outfit_history_for_user(user_id)
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
    invalidate_locations_for_user(user_id)
    invalidate_outfit_history_for_user(user_id)
    return location


@router.delete("/{user_id}/{location_id}")
def delete_location(user_id: int, location_id: int, db: Session = Depends(get_db)):
    location = ensure_location_for_user(db, user_id, location_id)

    db.delete(location)
    db.commit()
    invalidate_locations_for_user(user_id)
    invalidate_outfit_history_for_user(user_id)
    return {"message": "Локация удалена"}
