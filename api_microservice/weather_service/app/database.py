"""Re-export shared database session helpers for the weather service."""

from api_microservice.common.database import (
    Base,
    db_session,
    engine,
    get_db,
    get_read_db,
)

from .schema import ensure_schema

ensure_schema(engine)
Base.metadata.create_all(bind=engine)

__all__ = ["Base", "db_session", "engine", "get_db", "get_read_db"]
