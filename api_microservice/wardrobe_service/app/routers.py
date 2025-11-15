"""Endpoints for managing wardrobe items and outfits."""

from __future__ import annotations

from typing import List, Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .database import get_db
from .media import save_media
from .models import Clothes
from .schemas import (
    OutfitSuggestion,
    WardrobeItemCreate,
    WardrobeItemRead,
    WardrobeItemUpdate,
)


router = APIRouter(prefix="/wardrobe", tags=["wardrobe"])


def _apply_temperature_payload(item: Clothes, *, minimum: int | None, maximum: int | None) -> None:
    if minimum is None and maximum is None:
        return

    metadata = item.ai_metadata or {}
    temp_range: list[int] = []
    if minimum is not None:
        temp_range.append(int(minimum))
    if maximum is not None and (not temp_range or int(maximum) != temp_range[0]):
        temp_range.append(int(maximum))
    if temp_range:
        metadata["temp_c_range"] = temp_range
        item.ai_metadata = metadata


def _to_schema(item: Clothes) -> WardrobeItemRead:
    data = WardrobeItemRead.model_validate(
        {
            **{
                "id": item.id,
                "user_id": item.user_id,
                "name": item.name,
                "category": item.category,
                "season": item.season,
                "color": item.color,
                "material": item.material,
                "prompt_description": item.prompt_description,
                "care_instructions": item.care_instructions,
                "location_id": item.location_id,
                "created_at": item.created_at,
                "image_url": item.image_url,
            },
            "ai_metadata": item.ai_metadata,
            "temperature_min": item.temperature_min,
            "temperature_max": item.temperature_max,
        }
    )
    gallery = item.image_gallery
    if gallery:
        data.image_gallery = gallery
    return data


@router.post("/items", response_model=WardrobeItemRead, status_code=status.HTTP_201_CREATED)
def create_item(payload: WardrobeItemCreate, db: Session = Depends(get_db)) -> WardrobeItemRead:
    data = payload.model_dump(exclude={"ai_metadata", "temperature_min", "temperature_max"})
    item = Clothes(**data)
    if payload.ai_metadata is not None:
        item.ai_metadata = payload.ai_metadata
    _apply_temperature_payload(item, minimum=payload.temperature_min, maximum=payload.temperature_max)
    db.add(item)
    db.commit()
    db.refresh(item)
    return _to_schema(item)


@router.get("/items", response_model=List[WardrobeItemRead])
def list_items(
    user_id: Optional[int] = None,
    db: Session = Depends(get_db),
) -> List[WardrobeItemRead]:
    query = select(Clothes)
    if user_id is not None:
        query = query.where(Clothes.user_id == user_id)
    items = db.scalars(query).all()
    return [_to_schema(item) for item in items]


@router.get("/user/{user_id}", response_model=List[WardrobeItemRead])
def get_user_items(
    user_id: int,
    db: Session = Depends(get_db),
    location_id: Optional[int] = Query(default=None, description="Wardrobe location identifier"),
) -> List[WardrobeItemRead]:
    query = select(Clothes).where(Clothes.user_id == user_id)
    if location_id is not None:
        query = query.where(Clothes.location_id == location_id)
    items = db.scalars(query).all()
    return [_to_schema(item) for item in items]


@router.get("/items/{item_id}", response_model=WardrobeItemRead)
def get_item(item_id: int, db: Session = Depends(get_db)) -> WardrobeItemRead:
    item = db.get(Clothes, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return _to_schema(item)


@router.put("/items/{item_id}", response_model=WardrobeItemRead)
def update_item(
    item_id: int,
    payload: WardrobeItemUpdate,
    db: Session = Depends(get_db),
) -> WardrobeItemRead:
    item = db.get(Clothes, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        if field in {"ai_metadata", "temperature_min", "temperature_max"}:
            continue
        setattr(item, field, value)

    if payload.ai_metadata is not None:
        item.ai_metadata = payload.ai_metadata
    _apply_temperature_payload(
        item,
        minimum=payload.temperature_min,
        maximum=payload.temperature_max,
    )

    db.commit()
    db.refresh(item)
    return _to_schema(item)


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(item_id: int, db: Session = Depends(get_db)) -> None:
    item = db.get(Clothes, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    db.delete(item)
    db.commit()


@router.post("/items/{item_id}/image", response_model=WardrobeItemRead)
def upload_item_image(
    item_id: int, file: UploadFile = File(...), db: Session = Depends(get_db)
) -> WardrobeItemRead:
    item = db.get(Clothes, item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    url = save_media(file.file, file.filename)
    item.image_url = url
    db.commit()
    db.refresh(item)
    return _to_schema(item)


@router.get("/outfits/suggestions", response_model=OutfitSuggestion)
def get_outfit_suggestion(db: Session = Depends(get_db)) -> OutfitSuggestion:
    items = db.scalars(select(Clothes).limit(3)).all()
    if not items:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No items available for suggestion")

    return OutfitSuggestion(
        outfit_id=1,
        description="Simple recommendation placeholder",
        items=[_to_schema(item) for item in items],
    )
