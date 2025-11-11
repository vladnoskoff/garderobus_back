"""Pydantic schemas for wardrobe data."""

from datetime import datetime
from pydantic import BaseModel, HttpUrl


class WardrobeItemBase(BaseModel):
    name: str
    category: str
    color: str | None = None


class WardrobeItemCreate(WardrobeItemBase):
    image_url: HttpUrl | None = None


class WardrobeItemRead(WardrobeItemBase):
    id: int
    image_url: HttpUrl | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class OutfitSuggestion(BaseModel):
    outfit_id: int
    description: str
    items: list[WardrobeItemRead]
