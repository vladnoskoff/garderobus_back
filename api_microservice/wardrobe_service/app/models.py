"""ORM models for the wardrobe microservice."""

from __future__ import annotations

import json
from datetime import datetime
from typing import Any

from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
    select,
)
from sqlalchemy.orm import Mapped, Session, declarative_base, relationship


Base = declarative_base()


class WardrobeLocation(Base):
    __tablename__ = "wardrobe_locations"

    id: Mapped[int] = Column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    name: Mapped[str] = Column(String, nullable=False)
    created_at: Mapped[datetime | None] = Column(
        DateTime(timezone=True), server_default=func.now()
    )
    latitude: Mapped[float | None] = Column(Float, nullable=True)
    longitude: Mapped[float | None] = Column(Float, nullable=True)

    clothes: Mapped[list["Clothes"]] = relationship(
        "Clothes", back_populates="location", cascade="all, delete-orphan"
    )


class Clothes(Base):
    __tablename__ = "clothes"

    id: Mapped[int] = Column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = Column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = Column(String, nullable=False)
    category: Mapped[str] = Column(String, nullable=False)
    season: Mapped[str] = Column(String, nullable=False)
    color: Mapped[str] = Column(String, nullable=False)
    image_url: Mapped[str | None] = Column(String, nullable=True)
    material: Mapped[str | None] = Column(String, nullable=True)
    created_at: Mapped[datetime | None] = Column(DateTime, server_default=func.now())
    prompt_description: Mapped[str | None] = Column(Text, nullable=True)
    care_instructions: Mapped[str | None] = Column(Text, nullable=True)
    location_id: Mapped[int | None] = Column(
        Integer, ForeignKey("wardrobe_locations.id", ondelete="SET NULL"), nullable=True
    )

    metadata_entry: Mapped["ClothesMetadata" | None] = relationship(
        "ClothesMetadata",
        back_populates="clothes",
        cascade="all, delete-orphan",
        single_parent=True,
        uselist=False,
    )
    images: Mapped[list["ClothesImage"]] = relationship(
        "ClothesImage", back_populates="clothes", cascade="all, delete-orphan"
    )
    location: Mapped[WardrobeLocation | None] = relationship(
        "WardrobeLocation", back_populates="clothes"
    )

    def _metadata_dict(self) -> dict[str, Any]:
        payload = self.ai_metadata
        if isinstance(payload, dict):
            return payload
        return {}

    @property
    def ai_metadata(self) -> dict[str, Any] | None:
        entry = self.metadata_entry
        if entry is None or entry.data is None:
            return None
        if isinstance(entry.data, dict):
            return entry.data
        if isinstance(entry.data, str):
            try:
                return json.loads(entry.data)
            except (TypeError, json.JSONDecodeError):
                return {"raw": entry.data}
        return None

    @ai_metadata.setter
    def ai_metadata(self, value: Any) -> None:
        if value is None:
            if self.metadata_entry:
                self.metadata_entry.data = None
            return

        if isinstance(value, str):
            try:
                value = json.loads(value)
            except (TypeError, json.JSONDecodeError):
                value = {"raw": value}
        elif hasattr(value, "model_dump"):
            value = value.model_dump()
        elif hasattr(value, "dict"):
            value = value.dict()

        if self.metadata_entry is None:
            self.metadata_entry = ClothesMetadata(data=value)
        else:
            self.metadata_entry.data = value

    @property
    def temperature_min(self) -> int | None:
        temp_range = self._metadata_dict().get("temp_c_range")
        if isinstance(temp_range, (list, tuple)) and temp_range:
            try:
                return int(temp_range[0])
            except (TypeError, ValueError):
                return None
        return None

    @property
    def temperature_max(self) -> int | None:
        temp_range = self._metadata_dict().get("temp_c_range")
        if isinstance(temp_range, (list, tuple)):
            try:
                if len(temp_range) >= 2:
                    return int(temp_range[1])
                if len(temp_range) == 1:
                    return int(temp_range[0])
            except (TypeError, ValueError):
                return None
        return None

    @property
    def image_gallery(self) -> list[str]:
        gallery: list[str] = []
        if self.images:
            ordered = sorted(
                self.images,
                key=lambda item: (not item.is_primary, item.created_at or datetime.min),
            )
            gallery.extend([img.image_url for img in ordered if img.image_url])
        if not gallery and self.image_url:
            gallery.append(self.image_url)
        return gallery


class ClothesImage(Base):
    __tablename__ = "clothes_gallery_images"

    id: Mapped[int] = Column(Integer, primary_key=True, index=True)
    clothes_id: Mapped[int] = Column(
        Integer, ForeignKey("clothes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    image_url: Mapped[str] = Column(Text, nullable=False)
    is_primary: Mapped[bool] = Column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime | None] = Column(DateTime, server_default=func.now())

    clothes: Mapped[Clothes] = relationship("Clothes", back_populates="images")


class ClothesMetadata(Base):
    __tablename__ = "clothes_metadata"

    clothes_id: Mapped[int] = Column(
        Integer, ForeignKey("clothes.id", ondelete="CASCADE"), primary_key=True
    )
    data: Mapped[dict[str, Any] | None] = Column(JSON, nullable=True)

    clothes: Mapped[Clothes] = relationship("Clothes", back_populates="metadata_entry")


class MannequinImage(Base):
    __tablename__ = "mannequin_images"

    id: Mapped[int] = Column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = Column(Integer, nullable=False)
    location_id: Mapped[int | None] = Column(Integer, nullable=True)
    image_url: Mapped[str] = Column(Text, nullable=False)
    created_at: Mapped[datetime | None] = Column(DateTime, server_default=func.now())
    items: Mapped[dict[str, Any] | None] = Column(JSON, nullable=True)
    weather: Mapped[dict[str, Any] | None] = Column(JSON, nullable=True)


class Outfit(Base):
    __tablename__ = "outfits"

    id: Mapped[int] = Column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = Column(Integer, nullable=True, index=True)
    weather_id: Mapped[int | None] = Column(Integer, nullable=True)
    clothing_ids: Mapped[dict[str, Any]] = Column(JSON, nullable=False)
    created_at: Mapped[datetime | None] = Column(DateTime, server_default=func.now())
    rating: Mapped[int | None] = Column(Integer, nullable=True)
    image_url: Mapped[str | None] = Column(String, nullable=True)


class WearHistory(Base):
    __tablename__ = "wear_history"

    id: Mapped[int] = Column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = Column(Integer, nullable=True, index=True)
    clothing_id: Mapped[int] = Column(Integer, nullable=True, index=True)
    worn_at: Mapped[datetime | None] = Column(DateTime, server_default=func.now())


def refresh_ai_metadata(session: Session, item: Clothes) -> None:
    if item.metadata_entry is None:
        stmt = select(ClothesMetadata).where(ClothesMetadata.clothes_id == item.id)
        entry = session.scalars(stmt).first()
        if entry:
            item.metadata_entry = entry
