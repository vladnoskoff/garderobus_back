"""Helpers that orchestrate calls to downstream services."""

from typing import Any

import httpx

from .config import get_settings


async def fetch_json(url: str) -> Any:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        response.raise_for_status()
        return response.json()


async def get_user_profile(user_id: int) -> Any:
    settings = get_settings()
    return await fetch_json(f"{settings.auth_service_url}/users/{user_id}")


async def get_current_weather(lat: float, lon: float) -> Any:
    settings = get_settings()
    return await fetch_json(f"{settings.weather_service_url}/weather/current?lat={lat}&lon={lon}")


async def get_wardrobe_items() -> Any:
    settings = get_settings()
    return await fetch_json(f"{settings.wardrobe_service_url}/wardrobe/items")


async def get_ai_recommendation(task_id: str) -> Any:
    settings = get_settings()
    return await fetch_json(f"{settings.ai_service_url}/ai/recommendations/{task_id}")
