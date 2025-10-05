import base64
import json
from datetime import datetime
from typing import Iterable, List, Optional, Tuple

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db
import settings
from openai_client import get_openai_client

router = APIRouter(prefix="/ai", tags=["AI Recommendations"])

client = get_openai_client()

MANNEQUIN_DIR = settings.MANNEQUIN_IMAGE_DIR
MANNEQUIN_DIR.mkdir(parents=True, exist_ok=True)
MANNEQUIN_URL_PREFIX = settings.MANNEQUIN_IMAGE_URL_PREFIX.rstrip("/")


def _safe_metadata(item: models.Clothes) -> dict:
    payload = item.ai_metadata
    if not payload:
        return {}
    if isinstance(payload, dict):
        return payload
    try:
        return json.loads(payload)
    except (TypeError, json.JSONDecodeError):
        return {}


def _extract_temp_range(item: models.Clothes) -> Tuple[Optional[int], Optional[int]]:
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


def _filter_by_season(clothes: Iterable[models.Clothes], weather: models.Weather) -> List[models.Clothes]:
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

    def matches(item: models.Clothes) -> bool:
        value = (item.season or "").lower()
        return any(marker in value for marker in preferred_labels)

    return [item for item in clothes if matches(item)]


def _select_outfit(clothes: List[models.Clothes], weather: models.Weather) -> List[models.Clothes]:
    if not clothes:
        return []

    scored_items: List[tuple[models.Clothes, float]] = []
    for item in clothes:
        temp_range = _extract_temp_range(item)
        score = _temperature_score(weather.temperature, temp_range)
        scored_items.append((item, score))

    scored_items.sort(key=lambda pair: (pair[1], (pair[0].category or "").lower()))
    selected: List[models.Clothes] = []
    used_categories: set[str] = set()

    for item, _ in scored_items:
        category = (item.category or "").lower()
        if category and category in used_categories:
            continue
        selected.append(item)
        if category:
            used_categories.add(category)
        if len(selected) >= 4:
            break

    if len(selected) < 3:
        seasonal_candidates = _filter_by_season(clothes, weather)
        for item in seasonal_candidates:
            if item not in selected:
                selected.append(item)
            if len(selected) >= 3:
                break

    return selected[:4]


def _build_mannequin_prompt(items: List[models.Clothes], weather: models.Weather) -> str:
    lines = [
        "Create a hyperrealistic studio photograph of a faceless mannequin wearing a cohesive outfit.",
        "Use soft neutral lighting, clean white background, no logos or text.",
        f"Weather context: {weather.condition}, {weather.temperature}°C, humidity {weather.humidity}%, wind {weather.wind_speed or 0} m/s.",
        "Ensure the outfit feels comfortable for the current weather and coordinates colours harmoniously.",
        "Clothing items to include:",
    ]

    for item in items:
        base_description = item.prompt_description or f"{item.color} {item.category}"
        temp_min, temp_max = _extract_temp_range(item)
        climate_note = ""
        if temp_min is not None or temp_max is not None:
            if temp_min is not None and temp_max is not None:
                climate_note = f" (комфорт от {temp_min}°C до {temp_max}°C)"
            elif temp_min is not None:
                climate_note = f" (подходит при температуре от {temp_min}°C)"
            elif temp_max is not None:
                climate_note = f" (подходит до {temp_max}°C)"
        lines.append(f"- {base_description.strip()} (season: {item.season}){climate_note}")

    return "\n".join(lines)


def _save_mannequin_image(image_b64: str, user_id: int) -> str:
    filename = f"mannequin_{user_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}.png"
    file_path = MANNEQUIN_DIR / filename
    image_bytes = base64.b64decode(image_b64)
    with open(file_path, "wb") as output:
        output.write(image_bytes)
    if MANNEQUIN_URL_PREFIX:
        return f"{MANNEQUIN_URL_PREFIX}/{filename}"
    return f"/{filename}"


@router.get("/recommendation/{user_id}")
def ai_recommendation(user_id: int, db: Session = Depends(get_db)):
    outfits = (
        db.query(models.Outfit)
        .filter(models.Outfit.user_id == user_id)
        .order_by(models.Outfit.created_at.desc())
        .limit(10)
        .all()
    )

    if not outfits:
        raise HTTPException(status_code=404, detail="История нарядов пуста")

    weather = db.query(models.Weather).order_by(models.Weather.created_at.desc()).first()
    prompt_parts = []
    for outfit in outfits:
        clothing_items = db.query(models.Clothes).filter(models.Clothes.id.in_(outfit.clothing_ids)).all()
        if not clothing_items:
            continue
        formatted_items = []
        for item in clothing_items:
            temp_min, temp_max = _extract_temp_range(item)
            temp_text = ""
            if temp_min is not None and temp_max is not None:
                temp_text = f" (комфорт {temp_min}–{temp_max}°C)"
            elif temp_min is not None:
                temp_text = f" (от {temp_min}°C)"
            elif temp_max is not None:
                temp_text = f" (до {temp_max}°C)"
            formatted_items.append(
                f"{item.name} — категория: {item.category}, цвет: {item.color}, материал: {item.material or 'не указан'}, сезон: {item.season}{temp_text}"
            )
        prompt_parts.append(f"Наряд #{outfit.id}: " + "; ".join(formatted_items))

    if not prompt_parts:
        raise HTTPException(status_code=404, detail="Недостаточно данных для рекомендаций")

    weather_context = (
        f"Актуальная погода: {weather.temperature}°C, влажность {weather.humidity}%, ветер {weather.wind_speed or 0} м/с, условие: {weather.condition}."
        if weather
        else ""
    )

    prompt = (
        "Проанализируй мои последние наряды и предложи, как улучшить стиль, сочетания цветов и материалов. "
        "Дай практичные советы с учётом погодных условий и образа жизни. "
        "Ответь по-русски, структурируй рекомендации в виде списков.\n"
        + weather_context
        + "\n"
        + "\n".join(prompt_parts)
    )

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "Ты профессиональный стилист и имиджмейкер. Анализируй гардероб с учётом температурных диапазонов одежды,"
                        " погодных условий и повседневных задач клиента. Отвечай только на русском языке, лаконично и по делу,"
                        " используя структурированные списки и краткие абзацы."
                    ),
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.7,
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Не удалось получить рекомендации: {exc}") from exc

    message = response.choices[0].message.content if response.choices else None
    if not message:
        raise HTTPException(status_code=502, detail="AI вернул пустой ответ")

    return {"recommendation": message.strip()}


@router.get("/mannequin/{user_id}", response_model=schemas.MannequinResponse)
def generate_mannequin(user_id: int, db: Session = Depends(get_db)):
    weather = db.query(models.Weather).order_by(models.Weather.created_at.desc()).first()
    if not weather:
        raise HTTPException(status_code=404, detail="Нет погодных данных")

    clothes = db.query(models.Clothes).filter(models.Clothes.user_id == user_id).all()
    if not clothes:
        raise HTTPException(status_code=404, detail="Одежда не найдена")

    selected_items = _select_outfit(clothes, weather)
    if not selected_items:
        raise HTTPException(status_code=404, detail="Не удалось подобрать одежду для манекена")

    prompt = _build_mannequin_prompt(selected_items, weather)

    try:
        image_response = client.images.generate(
            model="gpt-image-1",
            prompt=prompt,
            size="1024x1024",
            quality="high",
            n=1,
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Не удалось сгенерировать изображение манекена: {exc}") from exc

    if not image_response.data:
        raise HTTPException(status_code=502, detail="AI не вернул изображение")

    image_url = _save_mannequin_image(image_response.data[0].b64_json, user_id)

    return schemas.MannequinResponse(
        image_url=image_url,
        weather=schemas.WeatherSnapshot(
            temperature=weather.temperature,
            humidity=weather.humidity,
            condition=weather.condition,
            wind_speed=weather.wind_speed,
        ),
        items=[schemas.MannequinItem.model_validate(item) for item in selected_items],
    )
