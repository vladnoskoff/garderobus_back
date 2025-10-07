import requests
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
import models, schemas
from database import get_db
from fastapi.responses import JSONResponse
from .location_utils import resolve_location_and_coordinates

router = APIRouter(prefix="/weather", tags=["Weather"])

@router.get("/coordinates")
def get_weather_by_coordinates(
    lat: float,
    lon: float,
    db: Session = Depends(get_db),
    api_key: str = None  # можно передать явно (вручную), иначе будет ошибка
):
    if not api_key:
        raise HTTPException(status_code=400, detail="API-ключ погоды не передан")

    base_url = "http://api.openweathermap.org/data/2.5"

    params = {
        "lat": lat,
        "lon": lon,
        "appid": api_key,
        "units": "metric",
        "lang": "ru"
    }

    current_response = requests.get(f"{base_url}/weather", params=params)
    if current_response.status_code != 200:
        raise HTTPException(status_code=400, detail="Ошибка при получении текущей погоды")
    current_data = current_response.json()

    forecast_response = requests.get(f"{base_url}/forecast", params=params)
    if forecast_response.status_code != 200:
        raise HTTPException(status_code=400, detail="Ошибка при получении прогноза")
    forecast_data = forecast_response.json()

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

    return {
        "id": weather_model.id,
        "temperature": temperature,
        "humidity": humidity,
        "condition": condition,
        "wind_speed": wind_speed,
        "pressure": pressure,
        "icon": icon,
        "forecast": forecast
    }

@router.get("/user/{user_id}")
def get_weather_for_user(
    user_id: int,
    location_id: Optional[int] = Query(default=None, description="Локация гардероба"),
    db: Session = Depends(get_db),
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user or not user.weather_api_key:
        raise HTTPException(status_code=404, detail="У пользователя нет координат или API-ключа")

    _, lat, lon = resolve_location_and_coordinates(db, user, location_id)

    return get_weather_by_coordinates(lat=lat, lon=lon, db=db, api_key=user.weather_api_key)


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

