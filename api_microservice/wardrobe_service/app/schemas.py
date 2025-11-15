"""Pydantic schemas for wardrobe data."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class WardrobeItemBase(BaseModel):
    user_id: int
    name: str
    category: str
    season: str
    color: Optional[str] = None
    material: Optional[str] = None
    prompt_description: Optional[str] = None
    care_instructions: Optional[str] = None
    temperature_min: Optional[int] = None
    temperature_max: Optional[int] = None
    location_id: Optional[int] = None


class WardrobeItemCreate(WardrobeItemBase):
    ai_metadata: Optional[dict] = None


class WardrobeItemUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    season: Optional[str] = None
    color: Optional[str] = None
    material: Optional[str] = None
    prompt_description: Optional[str] = None
    care_instructions: Optional[str] = None
    temperature_min: Optional[int] = None
    temperature_max: Optional[int] = None
    location_id: Optional[int] = None
    ai_metadata: Optional[dict] = None


class WardrobeItemRead(WardrobeItemBase):
    id: int
    image_url: Optional[str] = None
    created_at: datetime
    ai_metadata: Optional[dict] = None
    image_gallery: list[str] = Field(default_factory=list)

    model_config = {"from_attributes": True}


class OutfitSuggestion(BaseModel):
    outfit_id: int
    description: str
    items: list[WardrobeItemRead]
