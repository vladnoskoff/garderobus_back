"""SQLAlchemy models for the auth service."""

from sqlalchemy import Column, DateTime, Integer, String, func
from sqlalchemy.orm import declarative_base


Base = declarative_base()


class User(Base):
    """User account stored in the authentication database."""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
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

    @property
    def has_pin(self) -> bool:
        return bool(self.pin_hash)
