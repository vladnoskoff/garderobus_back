import hashlib
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session
import models, schemas
from database import get_db
import settings
from cache import cache
from .location_utils import resolve_location_and_coordinates
from services.http_client import (
    CircuitOpenError,
    HTTPRequestError,
    RateLimitExceededError,
    http_client,
)

router = APIRouter(prefix="/weather", tags=["Weather"])

def _weather_cache_key(lat: float, lon: float, api_key: str) -> str:
    hashed_key = hashlib.sha256(api_key.encode("utf-8")).hexdigest()[:16]
    return cache.make_key(
        "weather",
        f"api:{hashed_key}",
        f"lat:{lat:.4f}",
        f"lon:{lon:.4f}",
    )


@router.get("/coordinates")
def get_weather_by_coordinates(
    lat: float,
    lon: float,
    db: Session = Depends(get_db),
    api_key: Optional[str] = None,
):
    resolved_key = api_key or settings.OPENWEATHER_API_KEY
    if not resolved_key:
        raise HTTPException(status_code=500, detail="Не настроен API-ключ погоды")

    cache_key = _weather_cache_key(lat, lon, resolved_key)
    cached = cache.get_json(cache_key, resource="weather")
    if cached is not None:
        return cached

    base_url = "http://api.openweathermap.org/data/2.5"

    params = {
        "lat": lat,
        "lon": lon,
        "appid": resolved_key,
        "units": "metric",
        "lang": "ru"
    }

    try:
        current_response = http_client.get(
            f"{base_url}/weather", params=params, service_name="openweather"
        )
        current_response.raise_for_status()
        current_data = current_response.json()

        forecast_response = http_client.get(
            f"{base_url}/forecast", params=params, service_name="openweather"
        )
        forecast_response.raise_for_status()
        forecast_data = forecast_response.json()
    except RateLimitExceededError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    except (CircuitOpenError, HTTPRequestError) as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Ошибка при получении данных погоды") from exc

    # Сохраняем текущую погоду в БД
    temperature = float(current_data["main"]["temp"])
    humidity = int(current_data["main"]["humidity"])
    condition = current_data["weather"][0]["description"]
    wind_speed = float(current_data["wind"]["speed"])
    pressure = int(current_data["main"]["pressure"])
    icon = current_data["weather"][0]["icon"]

    weather_model = models.Weather(
        temperature=temperature,
        humidity=humidity,
        condition=condition,
        wind_speed=wind_speed,
    )
    db.add(weather_model)
    db.commit()
    db.refresh(weather_model)

    # Формируем прогноз
    forecast = []
    added_dates = set()
    for entry in forecast_data.get("list", []):
        date = entry["dt_txt"].split()[0]
        if date not in added_dates:
            added_dates.add(date)
            forecast.append({
                "date": entry["dt_txt"],
                "temp": entry["main"]["temp"],
                "condition": entry["weather"][0]["description"],
                "icon": entry["weather"][0]["icon"]
            })
        if len(added_dates) >= 3:
            break

    payload = {
        "id": weather_model.id,
        "temperature": temperature,
        "humidity": humidity,
        "condition": condition,
        "wind_speed": wind_speed,
        "pressure": pressure,
        "icon": icon,
        "forecast": forecast
    }

    cache.set_json(
        cache_key,
        jsonable_encoder(payload),
        ttl=settings.CACHE_TTL_WEATHER,
        resource="weather",
    )

    return payload

@router.get("/user/{user_id}")
def get_weather_for_user(
    user_id: int,
    location_id: Optional[int] = Query(default=None, description="Локация гардероба"),
    db: Session = Depends(get_db),
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    _, lat, lon = resolve_location_and_coordinates(db, user, location_id)

    user_key = cache.make_key(
        "weather",
        f"user:{user_id}",
        f"location:{location_id}" if location_id is not None else "location:all",
    )
    cached = cache.get_json(user_key, resource="weather")
    if cached is not None:
        return cached

    payload = get_weather_by_coordinates(
        lat=lat,
        lon=lon,
        db=db,
    )

    cache.set_json(
        user_key,
        jsonable_encoder(payload),
        ttl=settings.CACHE_TTL_WEATHER,
        resource="weather",
    )

    return payload


# @router.get("/{city}")
# def get_weather(city: str, db: Session = Depends(get_db)):
#     """
#     Получение текущей погоды и прогноза на 3 дня из OpenWeather API (без One Call 3.0)
#     """
#     API_KEY = settings.OPENWEATHER_API_KEY
#     base_url = "http://api.openweathermap.org/data/2.5"

#     # Текущая погода
#     current_params = {
#         "q": city,
#         "appid": API_KEY,
#         "units": "metric",
#         "lang": "ru"
#     }
#     current_response = requests.get(f"{base_url}/weather", params=current_params)
#     if current_response.status_code != 200:
#         raise HTTPException(status_code=400, detail="Ошибка при получении текущей погоды")
#     current_data = current_response.json()

#     # Прогноз на 5 дней (каждые 3 часа)
#     forecast_response = requests.get(f"{base_url}/forecast", params=current_params)
#     if forecast_response.status_code != 200:
#         raise HTTPException(status_code=400, detail="Ошибка при получении прогноза")
#     forecast_data = forecast_response.json()

#     # Сохраняем текущую погоду в БД
#     temperature = float(current_data["main"]["temp"])
#     humidity = int(current_data["main"]["humidity"])
#     condition = current_data["weather"][0]["description"]
#     wind_speed = float(current_data["wind"]["speed"])

#     weather_model = models.Weather(
#         temperature=temperature,
#         humidity=humidity,
#         condition=condition,
#         wind_speed=wind_speed
#     )
#     db.add(weather_model)
#     db.commit()
#     db.refresh(weather_model)

#     result = {
#         "temperature": temperature,
#         "humidity": humidity,
#         "condition": condition,
#         "wind_speed": wind_speed,
#         "pressure": int(current_data["main"]["pressure"]),  # <--- добавляем
#         "icon": current_data["weather"][0]["icon"],
#         "forecast": []
#     }

#     # Берём прогноз на ближайшие 3 дня (с шагом 1 день)
#     added_dates = set()
#     for entry in forecast_data.get("list", []):
#         date = entry["dt_txt"].split()[0]
#         if date not in added_dates:
#             added_dates.add(date)
#             result["forecast"].append({
#                 "date": entry["dt_txt"],
#                 "temp": entry["main"]["temp"],
#                 "condition": entry["weather"][0]["description"],
#                 "icon": entry["weather"][0]["icon"]
#             })
#         if len(added_dates) >= 3:
#             break

#     return JSONResponse(content=result, media_type="application/json; charset=utf-8")

