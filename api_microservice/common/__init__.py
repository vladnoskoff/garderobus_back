"""Shared utilities and configuration for the Garderobus microservices."""

from . import cache, settings
from .cache import (
    CacheService,
    CacheStatus,
    cache,
    cache_key,
    invalidate_clothes_for_user,
    invalidate_locations_for_user,
    invalidate_outfit_history_for_user,
    invalidate_weather_for_user,
)
from .database import (
    Base,
    SessionLocal,
    db_session,
    get_db,
    get_read_db,
)
from .messaging import EventMessage, publish_event
from .openai_client import get_openai_client, is_proxy_active

__all__ = [
    "Base",
    "CacheService",
    "CacheStatus",
    "EventMessage",
    "SessionLocal",
    "cache",
    "cache_key",
    "db_session",
    "get_db",
    "get_openai_client",
    "get_read_db",
    "invalidate_clothes_for_user",
    "invalidate_locations_for_user",
    "invalidate_outfit_history_for_user",
    "invalidate_weather_for_user",
    "is_proxy_active",
    "publish_event",
    "settings",
]
