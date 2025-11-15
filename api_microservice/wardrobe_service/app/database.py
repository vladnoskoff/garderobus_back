"""Database session helpers re-exported from the shared infrastructure."""

from api_microservice.common.database import (
    Base,
    db_session,
    engine,
    get_db,
    get_read_db,
)

from .schema import ensure_schema

# Ensure the wardrobe-related tables exist before the application serves traffic.
ensure_schema(engine)
Base.metadata.create_all(bind=engine)

__all__ = ["Base", "db_session", "engine", "get_db", "get_read_db"]
