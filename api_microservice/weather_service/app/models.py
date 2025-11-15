"""SQLAlchemy models used by the weather service."""

from __future__ import annotations

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.orm import declarative_base, relationship


Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    phone = Column(String(32), nullable=True)
    password_hash = Column(String(255), nullable=False)
    pin_hash = Column(String(255), nullable=True)
    openai_api_key = Column(String, nullable=True)
    weather_api_key = Column(String, nullable=True)
    location = Column(String, nullable=True)
    gender = Column(String, nullable=True)
    theme_preference = Column(String, nullable=False, default="light", server_default="light")
    language_preference = Column(String(10), nullable=False, default="ru", server_default="ru")
    style_preference = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class WardrobeLocation(Base):
    __tablename__ = "wardrobe_locations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    name = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    user = relationship("User", backref="locations")


class Weather(Base):
    __tablename__ = "weather"

    id = Column(Integer, primary_key=True, index=True)
    temperature = Column(Integer, nullable=False)
    humidity = Column(Integer, nullable=False)
    condition = Column(String, nullable=False)
    wind_speed = Column(Numeric, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
