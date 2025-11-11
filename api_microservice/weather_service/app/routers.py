"""Endpoints providing weather data."""

from datetime import datetime, timedelta, timezone
from functools import lru_cache
from typing import Any

from fastapi import APIRouter, Depends

from .config import get_settings
from .http_client import fetch_current_weather


router = APIRouter(prefix="/weather", tags=["weather"])


@lru_cache
def get_cache() -> dict[str, Any]:
    return {}


@router.get("/current")
async def get_current_weather(lat: float, lon: float, cache: dict = Depends(get_cache)) -> dict:
    cache_key = f"{lat},{lon}"
    settings = get_settings()
    entry = cache.get(cache_key)
    if entry:
        expires_at: datetime = entry["expires_at"]
        if expires_at > datetime.now(timezone.utc):
            return entry["data"]

    data = await fetch_current_weather(lat, lon)
    cache[cache_key] = {
        "data": data,
        "expires_at": datetime.now(timezone.utc) + timedelta(seconds=settings.cache_ttl_seconds),
    }
    return data
