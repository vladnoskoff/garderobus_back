"""HTTP client for interacting with the external weather provider."""

from functools import lru_cache
from typing import Any

import httpx

from .config import get_settings


@lru_cache
def get_client() -> httpx.AsyncClient:
    settings = get_settings()
    return httpx.AsyncClient(timeout=settings.http_timeout)


async def fetch_weather(endpoint: str, *, lat: float, lon: float) -> dict[str, Any]:
    settings = get_settings()
    params = {
        "lat": lat,
        "lon": lon,
        "appid": settings.openweathermap_api_key,
        "units": "metric",
        "lang": "ru",
    }
    client = get_client()
    response = await client.get(f"https://api.openweathermap.org/data/2.5/{endpoint}", params=params)
    response.raise_for_status()
    return response.json()
