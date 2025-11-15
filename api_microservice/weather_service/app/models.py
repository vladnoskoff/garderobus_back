"""SQLAlchemy models used by the weather service."""

from __future__ import annotations

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.orm import declarative_base, relationship


Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    location = Column(String, nullable=True)


class WardrobeLocation(Base):
    __tablename__ = "wardrobe_locations"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    name = Column(String, nullable=False)
    latitude = Column(Numeric(10, 6), nullable=True)
    longitude = Column(Numeric(10, 6), nullable=True)

    user = relationship("User", backref="locations")


class Weather(Base):
    __tablename__ = "weather"

    id = Column(Integer, primary_key=True, index=True)
    temperature = Column(Integer, nullable=False)
    humidity = Column(Integer, nullable=False)
    condition = Column(String, nullable=False)
    wind_speed = Column(Float, nullable=True)
    pressure = Column(Integer, nullable=True)
    icon = Column(String(16), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
