"""Read-through cache helpers used by service and route layers."""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session, load_only

from api import models
from api import settings
from api.cache import cache


class CachedQueryService:
    """Provides cached read access for common wardrobe lookups."""

    def get_user_locations(self, db: Session, user_id: int) -> List[models.WardrobeLocation]:
        cache_key = cache.make_key("locations", user_id)
        cached = cache.get_json(cache_key, resource="locations")
        if cached is not None:
            return cached  # type: ignore[return-value]

        locations = (
            db.query(models.WardrobeLocation)
            .options(load_only(models.WardrobeLocation.id, models.WardrobeLocation.name))
            .filter(models.WardrobeLocation.user_id == user_id)
            .order_by(models.WardrobeLocation.created_at.asc())
            .all()
        )
        cache.set_json(
            cache_key,
            jsonable_encoder(locations),
            ttl=settings.CACHE_TTL_LOCATIONS,
            resource="locations",
        )
        return locations

    def get_user_clothes(
        self, db: Session, user_id: int, *, location_id: Optional[int] = None
    ) -> List[models.Clothes]:
        location_segment = (
            f"location:{location_id}" if location_id is not None else "location:all"
        )
        key = cache.make_key("clothes", user_id, location_segment)
        cached = cache.get_json(key, resource="clothes")
        if cached is not None:
            return cached  # type: ignore[return-value]

        query = db.query(models.Clothes).filter(models.Clothes.user_id == user_id)
        if location_id is not None:
            query = query.filter(models.Clothes.location_id == location_id)

        clothes_items = (
            query.options(
                load_only(
                    models.Clothes.id,
                    models.Clothes.name,
                    models.Clothes.category,
                    models.Clothes.season,
                    models.Clothes.color,
                    models.Clothes.image_url,
                    models.Clothes.location_id,
                    models.Clothes.created_at,
                )
            )
            .all()
        )
        cache.set_json(
            key,
            jsonable_encoder(clothes_items),
            ttl=settings.CACHE_TTL_CLOTHES,
            resource="clothes",
        )
        return clothes_items

    def get_outfit_history(
        self, db: Session, user_id: int, *, location_id: Optional[int] = None
    ) -> list[Dict[str, Any]]:
        cache_key = cache.make_key(
            "outfit_history",
            user_id,
            f"location:{location_id}" if location_id is not None else "location:all",
        )

        cached = cache.get_json(cache_key, resource="outfit_history")
        if cached is not None:
            return cached  # type: ignore[return-value]

        outfits = (
            db.query(models.Outfit)
            .options(
                load_only(
                    models.Outfit.id,
                    models.Outfit.created_at,
                    models.Outfit.rating,
                    models.Outfit.image_url,
                    models.Outfit.weather_id,
                    models.Outfit.clothing_ids,
                    models.Outfit.user_id,
                )
            )
            .filter(models.Outfit.user_id == user_id)
            .order_by(models.Outfit.created_at.desc())
            .all()
        )

        if not outfits:
            return []

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
                .options(
                    load_only(
                        models.Clothes.id,
                        models.Clothes.name,
                        models.Clothes.category,
                        models.Clothes.season,
                        models.Clothes.color,
                        models.Clothes.image_url,
                        models.Clothes.location_id,
                    )
                )
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
                .options(load_only(models.WardrobeLocation.id, models.WardrobeLocation.name))
                .filter(models.WardrobeLocation.id.in_(location_ids))
                .all()
            )
            location_map = {loc.id: loc for loc in locations}

        weather_map: Dict[int, models.Weather] = {}
        if weather_ids:
            weather_entries = (
                db.query(models.Weather)
                .options(
                    load_only(
                        models.Weather.id,
                        models.Weather.temperature,
                        models.Weather.condition,
                        models.Weather.humidity,
                        models.Weather.wind_speed,
                    )
                )
                .filter(models.Weather.id.in_(weather_ids))
                .all()
            )
            weather_map = {w.id: w for w in weather_entries}

        history: List[Dict[str, Any]] = []
        for outfit in outfits:
            clothing_details: List[Dict[str, Any]] = []
            clothing_ids_for_outfit = [
                cid for cid in (outfit.clothing_ids or []) if isinstance(cid, int)
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
                    item.get("name") or item.get("category") for item in clothing_details
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


cached_queries = CachedQueryService()

__all__ = ["cached_queries", "CachedQueryService"]
