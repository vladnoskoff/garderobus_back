from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session
from api.database import get_db, get_read_db
from api import models
import random
from routes.weather import get_weather_by_coordinates  # Импорт функции погоды
from api import schemas
from typing import Any, Dict, List, Optional
from api import settings
from api.cache import cache, invalidate_outfit_history_for_user
from .location_utils import ensure_location_for_user, resolve_location_and_coordinates

router = APIRouter(prefix="/outfits", tags=["Outfits"])

@router.get("/{user_id}")
def get_outfit(
    user_id: int,
    location_id: Optional[int] = Query(default=None, description="Выбор гардероба по локации"),
    db: Session = Depends(get_db),
):
    """Выдаёт комплект одежды по погоде, используя координаты пользователя."""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    location, lat, lon = resolve_location_and_coordinates(db, user, location_id)

    # Получаем погоду по координатам с использованием системного API-ключа
    weather_data = get_weather_by_coordinates(lat=lat, lon=lon, db=db)
    if not weather_data:
        raise HTTPException(status_code=500, detail="Не удалось получить погоду")

    temperature = weather_data["temperature"]
    weather_id = weather_data["id"]

    # # Определяем сезон
    def get_season(temp):
        if temp >= 20:
            return "Лето"
        elif 10 <= temp < 20:
            return "Весна"
        elif 0 <= temp < 10:
            return "Осень"
        else:
            return "Зима"
    # def get_season(temp):
    #     if temp >= 20:
    #         return ["Лето"]
    #     elif 0 <= temp < 20:
    #         return ["Весна", "Осень"]
    #     else:
    #         return ["Зима"]

    current_season = get_season(temperature)

    # Получаем подходящую одежду пользователя
    clothes_query = db.query(models.Clothes).filter(models.Clothes.user_id == user_id)
    if location is not None:
        clothes_query = clothes_query.filter(models.Clothes.location_id == location.id)

    clothes = clothes_query.all()
    seasonal = [c for c in clothes if c.season.strip().lower() == current_season.lower()]
    # clothes = db.query(models.Clothes).filter(models.Clothes.user_id == user_id).all()
    # seasonal = [c for c in clothes if c.season.strip().lower() in [s.lower() for s in current_seasons]]


    def find_category(possible_names):
        matched = []
        for name in possible_names:
            for c in seasonal:
                if name.lower() in c.category.strip().lower():
                    matched.append(c)
        return random.choice(matched) if matched else None

    selected = {
        "головной убор": find_category(["кепка", "шапка", "панама"]),
        "верх": find_category(["футболка", "кофта", "куртка", "свитер", "рубашка"]),
        "низ": find_category(["штаны", "джинсы", "шорты"]),
        "обувь": find_category(["кроссовки", "ботинки", "туфли", "сланцы"]),
    }

    clothing_ids = [c.id for c in selected.values() if c]

    # Сохраняем образ
    outfit = models.Outfit(
        user_id=user_id,
        weather_id=weather_id,
        clothing_ids=clothing_ids
    )
    db.add(outfit)
    db.commit()
    db.refresh(outfit)

    invalidate_outfit_history_for_user(user_id)

    return {
        "outfit_id": outfit.id,
        "temperature": temperature,
        "season": current_season,
        "items": {
            part: {
                "name": item.name,
                "category": item.category,
                "image_url": item.image_url
            } if item else "Нет подходящей вещи"
            for part, item in selected.items()
        }
    }



@router.get("/history/{user_id}")
def get_outfit_history(
    user_id: int,
    location_id: Optional[int] = Query(
        default=None,
        description="Фильтрация истории по конкретной локации гардероба",
    ),
    db: Session = Depends(get_read_db),
):
    """Получение истории ранее собранных нарядов пользователя."""

    if location_id is not None:
        ensure_location_for_user(db, user_id, location_id)

    cache_key = cache.make_key(
        "outfit_history",
        user_id,
        f"location:{location_id}" if location_id is not None else "location:all",
    )

    cached = cache.get_json(cache_key, resource="outfit_history")
    if cached is not None:
        return cached

    outfits = (
        db.query(models.Outfit)
        .filter(models.Outfit.user_id == user_id)
        .order_by(models.Outfit.created_at.desc())
        .all()
    )

    if not outfits:
        return []

    # Собираем идентификаторы одежды, погод и локаций для выборки одним запросом
    clothing_ids: set[int] = set()
    weather_ids: set[int] = set()
    for outfit in outfits:
        if isinstance(outfit.clothing_ids, list):
            clothing_ids.update(
                cid for cid in outfit.clothing_ids if isinstance(cid, int)
            )
        if outfit.weather_id:
            weather_ids.add(outfit.weather_id)

    clothes_map: Dict[int, models.Clothes] = {}
    if clothing_ids:
        clothes = (
            db.query(models.Clothes)
            .filter(models.Clothes.id.in_(clothing_ids))
            .all()
        )
        clothes_map = {item.id: item for item in clothes}

    location_ids: set[int] = {
        item.location_id
        for item in clothes_map.values()
        if item.location_id is not None
    }
    location_map: Dict[int, models.WardrobeLocation] = {}
    if location_ids:
        locations = (
            db.query(models.WardrobeLocation)
            .filter(models.WardrobeLocation.id.in_(location_ids))
            .all()
        )
        location_map = {loc.id: loc for loc in locations}

    weather_map: Dict[int, models.Weather] = {}
    if weather_ids:
        weather_entries = (
            db.query(models.Weather)
            .filter(models.Weather.id.in_(weather_ids))
            .all()
        )
        weather_map = {w.id: w for w in weather_entries}

    history: List[Dict[str, Any]] = []
    for outfit in outfits:
        clothing_details: List[Dict[str, Any]] = []
        clothing_ids_for_outfit = [
            cid
            for cid in (outfit.clothing_ids or [])
            if isinstance(cid, int)
        ]

        for cid in clothing_ids_for_outfit:
            clothing = clothes_map.get(cid)
            if not clothing:
                continue

            location = (
                location_map.get(clothing.location_id)
                if clothing.location_id is not None
                else None
            )

            clothing_details.append(
                {
                    "id": clothing.id,
                    "name": clothing.name,
                    "category": clothing.category,
                    "season": clothing.season,
                    "color": clothing.color,
                    "image_url": clothing.image_url,
                    "location_id": clothing.location_id,
                    "location_name": location.name if location else None,
                }
            )

        if location_id is not None and not any(
            item.get("location_id") == location_id for item in clothing_details
        ):
            # Наряд не относится к выбранной локации
            continue

        preview_image = outfit.image_url
        if not preview_image:
            for item in clothing_details:
                image_url = item.get("image_url")
                if isinstance(image_url, str) and image_url.strip():
                    preview_image = image_url
                    break

        description_parts = [
            part
            for part in (
                item.get("name") or item.get("category")
                for item in clothing_details
            )
            if part
        ]
        description = ", ".join(description_parts) if description_parts else None

        location_names = [
            item.get("location_name")
            for item in clothing_details
            if item.get("location_name")
        ]
        location_name = location_names[0] if location_names else None

        weather = weather_map.get(outfit.weather_id) if outfit.weather_id else None

        history.append(
            {
                "id": outfit.id,
                "title": (
                    f"Наряд от {outfit.created_at.strftime('%d.%m.%Y %H:%M')}"
                    if outfit.created_at
                    else f"Наряд #{outfit.id}"
                ),
                "created_at": outfit.created_at.isoformat()
                if outfit.created_at
                else None,
                "rating": outfit.rating,
                "image_url": preview_image,
                "description": description,
                "items": clothing_details,
                "location_name": location_name,
                "weather": {
                    "temperature": weather.temperature,
                    "condition": weather.condition,
                    "humidity": weather.humidity,
                    "wind_speed": weather.wind_speed,
                }
                if weather
                else None,
            }
        )

    cache.set_json(
        cache_key,
        jsonable_encoder(history),
        ttl=settings.CACHE_TTL_OUTFITS,
        resource="outfit_history",
    )

    return history
    
# @router.put("/rate/{outfit_id}")
# def rate_outfit(outfit_id: int, rating: int, db: Session = Depends(get_db)):
#     """
#     Оценка наряда.

#     - **outfit_id**: Идентификатор наряда.
#     - **rating**: Оценка от 1 до 5 для наряда.

#     Обновляет рейтинг наряда, если он существует.
#     """
#     if rating < 1 or rating > 5:
#         raise HTTPException(status_code=400, detail="Рейтинг должен быть от 1 до 5")

#     outfit = db.query(models.Outfit).filter(models.Outfit.id == outfit_id).first()
#     if not outfit:
#         raise HTTPException(status_code=404, detail="Наряд не найден")

#     outfit.rating = rating
#     db.commit()
#     return {"message": "Рейтинг обновлён", "rating": rating}
