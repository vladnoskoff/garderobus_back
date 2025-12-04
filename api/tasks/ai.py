"""Shared helper utilities for AI-powered wardrobe features."""

from __future__ import annotations

import base64
import json
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from typing import Iterable, List, Optional, Tuple, Union
from uuid import uuid4

from celery import shared_task
from celery.utils.log import get_task_logger
from sqlalchemy.orm import Session

import models
import schemas
import settings
from cache import invalidate_outfit_history_for_user
from database import SessionLocal
from openai_client import get_openai_client
from routes.location_utils import resolve_location_and_coordinates
from routes.weather import get_weather_by_coordinates

MANNEQUIN_DIR = settings.MANNEQUIN_IMAGE_DIR
MANNEQUIN_DIR.mkdir(parents=True, exist_ok=True)

logger = get_task_logger(__name__)


def coerce_int(value: Optional[Union[int, float, Decimal]]) -> Optional[int]:
    """Convert numeric values that may be decimals to ints."""

    if value is None:
        return None
    if isinstance(value, Decimal):
        return int(round(float(value)))
    if isinstance(value, float):
        return int(round(value))
    return int(value)


def _safe_metadata(item) -> dict:
    payload = getattr(item, "ai_metadata", None)
    if not payload:
        return {}
    if isinstance(payload, dict):
        return payload
    try:
        return json.loads(payload)
    except (TypeError, json.JSONDecodeError):
        return {}


def extract_temp_range(item) -> Tuple[Optional[int], Optional[int]]:
    meta = _safe_metadata(item)
    min_temp: Optional[int] = None
    max_temp: Optional[int] = None

    range_from_meta = meta.get("temp_c_range") if isinstance(meta, dict) else None
    if range_from_meta and isinstance(range_from_meta, (list, tuple)):
        cleaned: list[int] = []
        for value in range_from_meta:
            try:
                cleaned.append(int(value))
            except (TypeError, ValueError):
                continue

        if cleaned:
            cleaned.sort()
            min_temp = cleaned[0]
            max_temp = cleaned[-1]

    return min_temp, max_temp


def _temperature_score(temperature: float, temp_range: Tuple[Optional[int], Optional[int]]) -> float:
    min_temp, max_temp = temp_range
    if min_temp is None and max_temp is None:
        return abs(temperature)
    if min_temp is None:
        return max(0, temperature - max_temp)  # type: ignore[arg-type]
    if max_temp is None:
        return max(0, min_temp - temperature)  # type: ignore[arg-type]
    if min_temp <= temperature <= max_temp:
        return 0
    if temperature < min_temp:
        return min_temp - temperature
    return temperature - max_temp  # type: ignore[return-value]


def filter_by_season(clothes: Iterable, weather) -> List:
    season_markers = {
        "зима": range(-50, 1),
        "весна": range(1, 16),
        "осень": range(5, 16),
        "лето": range(16, 60),
    }
    normalized_weather_temp = weather.temperature
    preferred_labels: List[str] = []
    for label, temp_range in season_markers.items():
        if normalized_weather_temp in temp_range:
            preferred_labels.append(label)

    if not preferred_labels:
        preferred_labels = ["универс", "демисезон"]

    def matches(item) -> bool:
        value = (getattr(item, "season", "") or "").lower()
        return any(marker in value for marker in preferred_labels)

    return [item for item in clothes if matches(item)]


def select_outfit(clothes: List, weather) -> List:
    if not clothes:
        return []

    scored_items: List[tuple] = []
    for item in clothes:
        temp_range = extract_temp_range(item)
        score = _temperature_score(weather.temperature, temp_range)
        scored_items.append((item, score))

    scored_items.sort(key=lambda pair: (pair[1], (getattr(pair[0], "category", "") or "").lower()))
    selected: List = []
    used_categories: set[str] = set()

    for item, _ in scored_items:
        category = (getattr(item, "category", "") or "").lower()
        if category and category in used_categories:
            continue
        selected.append(item)
        if category:
            used_categories.add(category)
        if len(selected) >= 4:
            break

    if len(selected) < 3:
        seasonal_candidates = filter_by_season(clothes, weather)
        for item in seasonal_candidates:
            if item not in selected:
                selected.append(item)
            if len(selected) >= 3:
                break

    return selected[:4]


def mannequin_gender_instruction(gender: Optional[str]) -> str:
    if not gender:
        return "Render a gender-neutral mannequin with average adult proportions."

    normalized = gender.strip().lower()
    if any(token in normalized for token in ("female", "woman", "жен")):
        return "Render a full-body female mannequin with realistic proportions for the listed garments."
    if any(token in normalized for token in ("male", "man", "муж")):
        return "Render a full-body male mannequin with realistic proportions for the listed garments."
    return f"Render a full-body mannequin that reflects the user's gender: {gender}."


def _item_reference_image(item) -> Optional[str]:
    """Return the first available image for an item to anchor the AI output."""

    gallery = getattr(item, "image_gallery", None)
    if not gallery:
        url = getattr(item, "image_url", None)
        return url if url else None
    if isinstance(gallery, list) and gallery:
        return gallery[0]
    return None


def build_mannequin_prompt(items: List, weather, gender: Optional[str]) -> str:
    lines = [
        "Create a hyperrealistic studio photograph of a faceless mannequin wearing a cohesive outfit.",
        "Frame the mannequin in a vertical 3:4 composition with generous head and foot margins so the full body is visible.",
        "Show the entire mannequin from head to toe in a neutral pose without any cropping.",
        "Use soft neutral lighting, clean white background, no logos or text.",
        f"Weather context: {weather.condition}, {weather.temperature}°C, humidity {weather.humidity}%, wind {getattr(weather, 'wind_speed', 0) or 0} m/s.",
        "Ensure the outfit feels comfortable for the current weather and coordinates colours harmoniously.",
        mannequin_gender_instruction(gender),
        "STRICT TRACE TASK: render exactly and only the wardrobe items listed below — no extra garments, layers, jewelry, bags, hats, scarves or props.",
        "Each listed item must appear exactly once. Unlisted clothing must never appear in any form.",
        "Treat reference photos as ground-truth: copy silhouettes, cuts, stitching lines, and logo placement precisely without creative changes.",
        "If an item has no logo/print in the reference, keep it 100% plain. Never add text, graphics, badges, or brand marks to plain items.",
        "If an item shows a logo or print, keep that graphic only on that garment in the same position and size; do not invent variants.",
        "Do not change base colours or materials. Do not swap colours between garments. Avoid patterns unless shown in the reference.",
        "If item details are unclear, choose the simplest unbranded interpretation rather than inventing new designs.",
        "If multiple items are listed, do not blend their branding or designs — keep every piece faithful to its own description only.",
        "Before finalizing the image, double-check: no unlisted garments, no extra logos, each item copied faithfully.",
        "Clothing items to include (each must appear once):",
    ]

    for item in items:
        base_description = getattr(item, "prompt_description", None) or f"{getattr(item, 'color', '')} {getattr(item, 'category', '')}"
        temp_min, temp_max = extract_temp_range(item)
        climate_note = ""
        if temp_min is not None or temp_max is not None:
            if temp_min is not None and temp_max is not None:
                climate_note = f" (комфорт от {temp_min}°C до {temp_max}°C)"
            elif temp_min is not None:
                climate_note = f" (подходит при температуре от {temp_min}°C)"
            elif temp_max is not None:
                climate_note = f" (подходит до {temp_max}°C)"
        reference_image = _item_reference_image(item)
        reference_note = (
            f" Reference image: {reference_image}. Copy its colour, silhouette, seams, and visible logos exactly; do not add or move any graphics."
            if reference_image
            else ""
        )
        lines.append(
            f"- {base_description.strip()} (season: {getattr(item, 'season', None)}){climate_note}.{reference_note}"
        )

    return "\n".join(lines)


def save_mannequin_image(image_b64: str, user_id: int, location_segment: str) -> str:
    """Persist a mannequin image to disk and return the public URL."""

    filename = f"mannequin_{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid4().hex}.png"
    target_dir: Path = MANNEQUIN_DIR / str(user_id) / location_segment
    target_dir.mkdir(parents=True, exist_ok=True)

    file_path = target_dir / filename
    image_bytes = base64.b64decode(image_b64)
    with open(file_path, "wb") as output:
        output.write(image_bytes)

    relative_path = f"{user_id}/{location_segment}/{filename}"
    url_prefix = settings.MANNEQUIN_IMAGE_URL_PREFIX.rstrip("/") if settings.MANNEQUIN_IMAGE_URL_PREFIX else None
    if url_prefix:
        return f"{url_prefix}/{relative_path}"

    return f"/mannequins/{relative_path}"


def _serialize_mannequin_item(item: models.Clothes) -> schemas.MannequinItem:
    return schemas.MannequinItem(
        id=item.id,
        name=item.name,
        category=item.category,
        color=item.color,
        material=item.material,
        season=item.season,
        prompt_description=item.prompt_description,
    )


def _prepare_weather_snapshot(payload: dict) -> schemas.WeatherSnapshot:
    return schemas.WeatherSnapshot(
        temperature=coerce_int(payload.get("temperature")),
        humidity=coerce_int(payload.get("humidity")),
        condition=str(payload.get("condition", "")),
        wind_speed=coerce_int(payload.get("wind_speed")),
    )


def _mannequin_location_segment(location_id: Optional[int]) -> str:
    return f"location:{location_id}" if location_id is not None else "location:all"


def _build_inline_error(detail: str, status_code: int = 500) -> dict:
    return {"status": "error", "status_code": status_code, "detail": detail}


@shared_task(bind=True, name="generate_mannequin_task")
def generate_mannequin_task(self, *, user_id: int, location_id: Optional[int] = None) -> dict:
    """Generate a mannequin image strictly from the user's wardrobe items."""

    with SessionLocal() as db:  # type: Session
        user: Optional[models.User] = db.query(models.User).get(user_id)
        if not user:
            return _build_inline_error("Пользователь не найден", status_code=404)

        try:
            location, lat, lon = resolve_location_and_coordinates(db, user, location_id)
        except Exception as exc:  # pragma: no cover - defensive for runtime errors
            logger.exception("Failed to resolve location for mannequin task")
            return _build_inline_error(str(exc), status_code=400)

        try:
            weather_payload = get_weather_by_coordinates(lat=lat, lon=lon, db=db)
        except Exception as exc:  # pragma: no cover - external API may fail
            logger.exception("Failed to fetch weather for mannequin task")
            return _build_inline_error(str(exc), status_code=502)

        clothes_query = db.query(models.Clothes).filter(models.Clothes.user_id == user_id)
        if location is not None:
            clothes_query = clothes_query.filter(models.Clothes.location_id == location.id)

        clothes = clothes_query.all()
        if not clothes:
            return _build_inline_error("У пользователя нет одежды для генерации")

        weather = _prepare_weather_snapshot(weather_payload)
        selected_items = select_outfit(clothes, weather)
        if not selected_items:
            return _build_inline_error("Не удалось подобрать вещи для манекена")

        prompt = build_mannequin_prompt(selected_items, weather, user.gender)

        try:
            client = get_openai_client()
            response = client.images.generate(
                model="gpt-image-1",
                prompt=prompt,
                size="1024x1536",
                quality="hd",
                n=1,
                response_format="b64_json",
            )
            image_b64 = response.data[0].b64_json  # type: ignore[assignment]
        except Exception as exc:  # pragma: no cover - depends on external API
            logger.exception("Image generation failed for mannequin task")
            return _build_inline_error(str(exc))

        location_segment = _mannequin_location_segment(location_id)
        image_url = save_mannequin_image(image_b64, user_id, location_segment)

        mannequin_items = [_serialize_mannequin_item(item) for item in selected_items]
        mannequin_record = models.MannequinImage(
            user_id=user_id,
            location_id=location.id if location else None,
            image_url=image_url,
            items=[item.model_dump() for item in mannequin_items],
            weather=weather.model_dump(),
        )
        db.add(mannequin_record)
        db.commit()

        invalidate_outfit_history_for_user(user_id)

        return {
            "status": "success",
            "result": schemas.MannequinResponse(
                image_url=image_url,
                weather=weather,
                items=mannequin_items,
            ).model_dump(),
        }


@shared_task(bind=True, name="generate_recommendation_task")
def generate_recommendation_task(self, *, user_id: int) -> dict:
    """Produce stylist recommendations based on recent outfits and wardrobe."""

    with SessionLocal() as db:  # type: Session
        user: Optional[models.User] = db.query(models.User).get(user_id)
        if not user:
            return _build_inline_error("Пользователь не найден", status_code=404)

        outfits = (
            db.query(models.Outfit)
            .filter(models.Outfit.user_id == user_id)
            .order_by(models.Outfit.created_at.desc())
            .limit(10)
            .all()
        )

        clothing_ids: list[int] = []
        weather_ids: list[int] = []
        for outfit in outfits:
            if isinstance(outfit.clothing_ids, list):
                clothing_ids.extend(
                    cid for cid in outfit.clothing_ids if isinstance(cid, int)
                )
            if outfit.weather_id:
                weather_ids.append(outfit.weather_id)

        clothes_map: dict[int, models.Clothes] = {}
        if clothing_ids:
            clothes = (
                db.query(models.Clothes)
                .filter(models.Clothes.id.in_(set(clothing_ids)))
                .all()
            )
            clothes_map = {item.id: item for item in clothes}

        weather_map: dict[int, models.Weather] = {}
        if weather_ids:
            weathers = (
                db.query(models.Weather)
                .filter(models.Weather.id.in_(set(weather_ids)))
                .all()
            )
            weather_map = {item.id: item for item in weathers}

        history_snapshot: list[dict] = []
        for outfit in outfits:
            clothing_details = []
            for cid in outfit.clothing_ids or []:
                item = clothes_map.get(cid)
                if not item:
                    continue
                clothing_details.append(_serialize_mannequin_item(item).model_dump())

            weather_obj = weather_map.get(outfit.weather_id)
            weather_payload = None
            if weather_obj:
                weather_payload = {
                    "temperature": coerce_int(weather_obj.temperature),
                    "humidity": coerce_int(weather_obj.humidity),
                    "condition": getattr(weather_obj, "condition", ""),
                    "wind_speed": coerce_int(getattr(weather_obj, "wind_speed", None)),
                }

            history_snapshot.append(
                {
                    "created_at": outfit.created_at.isoformat() if outfit.created_at else None,
                    "items": clothing_details,
                    "weather": weather_payload,
                }
            )

        prompt_lines = [
            "Act as a personal stylist. Provide concise outfit recommendations based on the user's recent looks and wardrobe.",
            "Avoid suggesting items the user does not own; keep recommendations within the listed wardrobe pieces.",
            "Recent outfits (newest first):",
        ]
        for entry in history_snapshot:
            prompt_lines.append(json.dumps(entry, ensure_ascii=False))

        wardrobe_items = db.query(models.Clothes).filter(models.Clothes.user_id == user_id).all()
        prompt_lines.append("Wardrobe items:")
        for item in wardrobe_items:
            prompt_lines.append(json.dumps(_serialize_mannequin_item(item).model_dump(), ensure_ascii=False))

        try:
            client = get_openai_client()
            completion = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are a concise, practical fashion stylist."},
                    {"role": "user", "content": "\n".join(prompt_lines)},
                ],
                max_tokens=500,
            )
            advice = completion.choices[0].message.content if completion.choices else ""
        except Exception as exc:  # pragma: no cover - external API may fail
            logger.exception("Recommendation generation failed")
            return _build_inline_error(str(exc))

        return {
            "status": "success",
            "result": {"recommendation": advice},
        }


__all__ = [
    "build_mannequin_prompt",
    "coerce_int",
    "extract_temp_range",
    "filter_by_season",
    "generate_mannequin_task",
    "generate_recommendation_task",
    "mannequin_gender_instruction",
    "save_mannequin_image",
    "select_outfit",
]