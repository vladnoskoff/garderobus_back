"""Endpoints providing weather data."""

from __future__ import annotations

import asyncio
import hashlib
from datetime import datetime, timedelta, timezone
from functools import lru_cache
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session

from .config import get_settings
from .database import get_db
from .http_client import fetch_weather
from .models import User, WardrobeLocation, Weather


router = APIRouter(prefix="/weather", tags=["weather"])


@lru_cache
def get_cache() -> dict[str, Any]:
    return {}


def _weather_cache_key(lat: float, lon: float, api_key: str) -> str:
    hashed_key = hashlib.sha256(api_key.encode("utf-8")).hexdigest()[:16]
    return f"weather:lat:{lat:.4f}:lon:{lon:.4f}:api:{hashed_key}"


async def _fetch_weather_payload(lat: float, lon: float) -> dict[str, Any]:
    current_data, forecast_data = await asyncio.gather(
        fetch_weather("weather", lat=lat, lon=lon),
        fetch_weather("forecast", lat=lat, lon=lon),
    )

    temperature = float(current_data["main"]["temp"])
    humidity = int(current_data["main"]["humidity"])
    condition = current_data["weather"][0]["description"]
    wind_speed = float(current_data["wind"].get("speed", 0))
    pressure = int(current_data["main"].get("pressure", 0))
    icon = current_data["weather"][0].get("icon")

    forecast: list[dict[str, Any]] = []
    added_dates: set[str] = set()
    for entry in forecast_data.get("list", []):
        date = entry["dt_txt"].split()[0]
        if date in added_dates:
            continue
        added_dates.add(date)
        forecast.append(
            {
                "date": entry["dt_txt"],
                "temp": entry["main"].get("temp"),
                "condition": entry["weather"][0].get("description"),
                "icon": entry["weather"][0].get("icon"),
            }
        )
        if len(added_dates) >= 3:
            break

    return {
        "temperature": temperature,
        "humidity": humidity,
        "condition": condition,
        "wind_speed": wind_speed,
        "pressure": pressure,
        "icon": icon,
        "forecast": forecast,
    }


async def _get_or_create_weather_entry(
    lat: float,
    lon: float,
    cache: dict,
) -> dict[str, Any]:
    settings = get_settings()
    cache_key = _weather_cache_key(lat, lon, settings.openweathermap_api_key)
    entry = cache.get(cache_key)
    now = datetime.now(timezone.utc)
    if entry and entry["expires_at"] > now:
        return entry["data"]

    payload = await _fetch_weather_payload(lat, lon)
    cache[cache_key] = {
        "data": payload,
        "expires_at": now + timedelta(seconds=settings.cache_ttl_seconds),
    }
    return payload


@router.get("/coordinates")
async def get_weather_by_coordinates(
    lat: float,
    lon: float,
    cache: dict = Depends(get_cache),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    payload = await _get_or_create_weather_entry(lat, lon, cache)

    weather_model = Weather(
        temperature=int(payload["temperature"]),
        humidity=int(payload["humidity"]),
        condition=str(payload["condition"]),
        wind_speed=float(payload.get("wind_speed", 0) or 0),
        pressure=int(payload.get("pressure", 0) or 0),
        icon=payload.get("icon"),
    )
    db.add(weather_model)
    db.commit()
    db.refresh(weather_model)

    response = {"id": weather_model.id, **payload}
    return response


@router.get("/user/{user_id}")
async def get_weather_for_user(
    user_id: int,
    cache: dict = Depends(get_cache),
    db: Session = Depends(get_db),
    location_id: Optional[int] = Query(default=None, description="Wardrobe location identifier"),
) -> dict[str, Any]:
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    if location_id is None:
        if not user.location:
            raise HTTPException(status_code=400, detail="Для пользователя не заданы координаты")
        try:
            lat, lon = map(float, user.location.split(","))
        except Exception as exc:  # pragma: no cover - defensive parsing
            raise HTTPException(status_code=400, detail="Некорректный формат координат пользователя") from exc
    else:
        location = (
            db.query(WardrobeLocation)
            .filter(WardrobeLocation.id == location_id, WardrobeLocation.user_id == user_id)
            .first()
        )
        if not location:
            raise HTTPException(status_code=404, detail="Локация не найдена для пользователя")
        if location.latitude is None or location.longitude is None:
            raise HTTPException(status_code=400, detail="Для выбранной локации не заданы координаты")
        lat, lon = float(location.latitude), float(location.longitude)

    payload = await _get_or_create_weather_entry(lat, lon, cache)
    return jsonable_encoder(payload)
