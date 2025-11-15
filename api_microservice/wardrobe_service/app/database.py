"""Database session helpers for the wardrobe service."""

from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .config import get_settings
from .models import Base
from .schema import ensure_schema


def _create_engine():
    settings = get_settings()
    engine = create_engine(settings.database_url, future=True)
    ensure_schema(engine)
    Base.metadata.create_all(bind=engine)
    return engine


_engine = _create_engine()
SessionLocal = sessionmaker(bind=_engine, expire_on_commit=False, class_=Session)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
