"""Database utilities for the weather service."""

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .config import get_settings
from .models import Base


def _create_engine():
    settings = get_settings()
    return create_engine(settings.database_url, future=True)


_engine = _create_engine()
SessionLocal = sessionmaker(bind=_engine, expire_on_commit=False, class_=Session)


def get_db() -> Generator[Session, None, None]:
    Base.metadata.create_all(_engine)
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
