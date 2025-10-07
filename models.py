import json
from typing import Optional

from sqlalchemy import Column, Integer, String, ForeignKey, JSON, TIMESTAMP, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)
    openai_api_key = Column(String, nullable=True)
    weather_api_key = Column(String, nullable=True)
    location = Column(String, nullable=True)
    gender = Column(String, nullable=True)

    locations = relationship(
        "WardrobeLocation",
        back_populates="user",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

class Clothes(Base):
    __tablename__ = "clothes"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    name = Column(String, nullable=False)
    category = Column(String, nullable=False)
    season = Column(String, nullable=False)
    color = Column(String, nullable=False)
    material = Column(String, nullable=True)
    image_url = Column(String, nullable=True)
    created_at = Column(TIMESTAMP, default=func.now())
    prompt_description = Column(Text, nullable=True)
    care_instructions = Column(Text, nullable=True)
    location_id = Column(Integer, ForeignKey("wardrobe_locations.id", ondelete="SET NULL"), nullable=True)
    ai_metadata = Column(JSON, nullable=True)

    def _metadata_dict(self) -> dict:
        if not self.ai_metadata:
            return {}
        if isinstance(self.ai_metadata, dict):
            return self.ai_metadata
        try:
            return json.loads(self.ai_metadata)
        except (TypeError, json.JSONDecodeError):
            return {}

    @property
    def temperature_min(self) -> Optional[int]:
        data = self._metadata_dict()
        temp_range = data.get("temp_c_range")
        if isinstance(temp_range, (list, tuple)) and temp_range:
            try:
                return int(temp_range[0])
            except (TypeError, ValueError):
                return None
        return None

    @property
    def temperature_max(self) -> Optional[int]:
        data = self._metadata_dict()
        temp_range = data.get("temp_c_range")
        if isinstance(temp_range, (list, tuple)):
            try:
                if len(temp_range) >= 2:
                    return int(temp_range[1])
                if len(temp_range) == 1:
                    return int(temp_range[0])
            except (TypeError, ValueError):
                return None
        return None

    metadata_entry = relationship(
        "ClothesMetadata",
        uselist=False,
        back_populates="clothes",
        cascade="all, delete-orphan",
        passive_deletes=True,
        single_parent=True,
    )
    location = relationship("WardrobeLocation", back_populates="clothes")

    @property
    def ai_metadata(self) -> Optional[dict]:
        if not self.metadata_entry:
            return None
        payload = self.metadata_entry.data
        if not payload:
            return None
        if isinstance(payload, dict):
            return payload
        try:
            return json.loads(payload)
        except (TypeError, json.JSONDecodeError):
            return None

    @ai_metadata.setter
    def ai_metadata(self, value):  # type: ignore[override]
        if value is None:
            if self.metadata_entry:
                self.metadata_entry.data = None
            return

        if isinstance(value, str):
            try:
                value = json.loads(value)
            except (TypeError, json.JSONDecodeError):
                value = {"raw": value}

        if hasattr(value, "model_dump"):
            value = value.model_dump()  # type: ignore[assignment]
        elif hasattr(value, "dict"):
            value = value.dict()  # type: ignore[assignment]

        if self.metadata_entry is None:
            self.metadata_entry = ClothesMetadata(data=value)
        else:
            self.metadata_entry.data = value

    def _metadata_dict(self) -> dict:
        payload = self.ai_metadata
        if isinstance(payload, dict):
            return payload
        return {}

    @property
    def temperature_min(self) -> Optional[int]:
        data = self._metadata_dict()
        temp_range = data.get("temp_c_range")
        if isinstance(temp_range, (list, tuple)) and temp_range:
            try:
                return int(temp_range[0])
            except (TypeError, ValueError):
                return None
        return None

    @property
    def temperature_max(self) -> Optional[int]:
        data = self._metadata_dict()
        temp_range = data.get("temp_c_range")
        if isinstance(temp_range, (list, tuple)):
            try:
                if len(temp_range) >= 2:
                    return int(temp_range[1])
                if len(temp_range) == 1:
                    return int(temp_range[0])
            except (TypeError, ValueError):
                return None
        return None

    metadata_entry = relationship(
        "ClothesMetadata",
        uselist=False,
        back_populates="clothes",
        cascade="all, delete-orphan",
        passive_deletes=True,
        single_parent=True,
    )

    @property
    def ai_metadata(self) -> Optional[dict]:
        if not self.metadata_entry:
            return None
        payload = self.metadata_entry.data
        if not payload:
            return None
        if isinstance(payload, dict):
            return payload
        try:
            return json.loads(payload)
        except (TypeError, json.JSONDecodeError):
            return None

    @ai_metadata.setter
    def ai_metadata(self, value):  # type: ignore[override]
        if value is None:
            if self.metadata_entry:
                self.metadata_entry.data = None
            return

        if isinstance(value, str):
            try:
                value = json.loads(value)
            except (TypeError, json.JSONDecodeError):
                value = {"raw": value}

        if hasattr(value, "model_dump"):
            value = value.model_dump()  # type: ignore[assignment]
        elif hasattr(value, "dict"):
            value = value.dict()  # type: ignore[assignment]

        if self.metadata_entry is None:
            self.metadata_entry = ClothesMetadata(data=value)
        else:
            self.metadata_entry.data = value

    def _metadata_dict(self) -> dict:
        payload = self.ai_metadata
        if isinstance(payload, dict):
            return payload
        return {}

    @property
    def temperature_min(self) -> Optional[int]:
        data = self._metadata_dict()
        temp_range = data.get("temp_c_range")
        if isinstance(temp_range, (list, tuple)) and temp_range:
            try:
                return int(temp_range[0])
            except (TypeError, ValueError):
                return None
        return None

    @property
    def temperature_max(self) -> Optional[int]:
        data = self._metadata_dict()
        temp_range = data.get("temp_c_range")
        if isinstance(temp_range, (list, tuple)):
            try:
                if len(temp_range) >= 2:
                    return int(temp_range[1])
                if len(temp_range) == 1:
                    return int(temp_range[0])
            except (TypeError, ValueError):
                return None
        return None

class Weather(Base):
    __tablename__ = "weather"

    id = Column(Integer, primary_key=True, index=True)
    temperature = Column(Integer, nullable=False)
    humidity = Column(Integer, nullable=False)
    condition = Column(String, nullable=False)
    wind_speed = Column(Integer, nullable=True)
    created_at = Column(TIMESTAMP, default=func.now())

class Outfit(Base):
    __tablename__ = "outfits"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    weather_id = Column(Integer, ForeignKey("weather.id", ondelete="CASCADE"))
    clothing_ids = Column(JSON, nullable=False)
    image_url = Column(String, nullable=True)
    created_at = Column(TIMESTAMP, default=func.now())
    rating = Column(Integer, nullable=True)

class WearHistory(Base):
    __tablename__ = "wear_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    clothing_id = Column(Integer, ForeignKey("clothes.id", ondelete="CASCADE"))
    worn_at = Column(TIMESTAMP, default=func.now())


class ClothesMetadata(Base):
    __tablename__ = "clothes_metadata"

    clothes_id = Column(Integer, ForeignKey("clothes.id", ondelete="CASCADE"), primary_key=True)
    data = Column(JSON, nullable=True)

    clothes = relationship("Clothes", back_populates="metadata_entry")


class WardrobeLocation(Base):
    __tablename__ = "wardrobe_locations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    name = Column(String, nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())

    user = relationship("User", back_populates="locations")
    clothes = relationship("Clothes", back_populates="location")
