"""Database utilities for the auth service."""

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from .config import get_settings
from .models import Base
from .schema import ensure_schema


_settings = get_settings()
_engine = create_engine(_settings.database_url, future=True)
ensure_schema(_engine)
SessionLocal = sessionmaker(bind=_engine, expire_on_commit=False)

Base.metadata.create_all(bind=_engine)


def get_db() -> Generator[Session, None, None]:
    """Yield a database session for dependency injection."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
