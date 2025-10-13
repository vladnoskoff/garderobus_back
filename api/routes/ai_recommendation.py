import base64
import json
from datetime import datetime
from decimal import Decimal
from uuid import uuid4
from typing import Iterable, List, Optional, Tuple, Union

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db
import settings
from openai_client import get_openai_client
from .location_utils import ensure_location_for_user

router = APIRouter(prefix="/ai", tags=["AI Recommendations"])

client = get_openai_client()

MANNEQUIN_DIR = settings.MANNEQUIN_IMAGE_DIR
MANNEQUIN_DIR.mkdir(parents=True, exist_ok=True)
MANNEQUIN_URL_PREFIX = settings.MANNEQUIN_IMAGE_URL_PREFIX.rstrip("/")


def _coerce_int(value: Optional[Union[int, float, Decimal]]) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, Decimal):
        return int(round(float(value)))
    if isinstance(value, float):
        return int(round(value))
    return int(value)


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


def _temperature_score(
    temperature: float, temp_range: Tuple[Optional[int], Optional[int]]
) -> float:
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


def _filter_by_season(
    clothes: Iterable[models.Clothes], weather: models.Weather
) -> List[models.Clothes]:
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


def _select_outfit(
    clothes: List[models.Clothes], weather: models.Weather
) -> List[models.Clothes]:
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


def _mannequin_gender_instruction(gender: Optional[str]) -> str:
    if not gender:
        return "Render a gender-neutral mannequin with average adult proportions."

    normalized = gender.strip().lower()
    if any(token in normalized for token in ("female", "woman", "жен")):
        return "Render a full-body female mannequin with realistic proportions for the listed garments."
    if any(token in normalized for token in ("male", "man", "муж")):
        return "Render a full-body male mannequin with realistic proportions for the listed garments."
    return f"Render a full-body mannequin that reflects the user's gender: {gender}."


def _build_mannequin_prompt(
    items: List[models.Clothes],
    weather: models.Weather,
    gender: Optional[str],
) -> str:
    lines = [
        "Create a hyperrealistic studio photograph of a faceless mannequin wearing a cohesive outfit.",
        "Frame the mannequin in a vertical 3:4 composition with generous head and foot margins so the full body is visible.",
        "Show the entire mannequin from head to toe in a neutral pose without any cropping.",
        "Use soft neutral lighting, clean white background, no logos or text.",
        f"Weather context: {weather.condition}, {weather.temperature}°C, humidity {weather.humidity}%, wind {weather.wind_speed or 0} m/s.",
        "Ensure the outfit feels comfortable for the current weather and coordinates colours harmoniously.",
        _mannequin_gender_instruction(gender),
        "Only use the clothing items listed below. Do not add extra garments, accessories or props.",
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
        lines.append(
            f"- {base_description.strip()} (season: {item.season}){climate_note}"
        )

    return "\n".join(lines)


def _save_mannequin_image(
    image_b64: str, user_id: int, location_segment: str, request: Request
) -> str:
    filename = f"mannequin_{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid4().hex}.png"
    target_dir = MANNEQUIN_DIR / str(user_id) / location_segment

    try:
        target_dir.mkdir(parents=True, exist_ok=True)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Не удалось подготовить директорию манекенов: {exc}",
        ) from exc

    file_path = target_dir / filename
    image_bytes = base64.b64decode(image_b64)
    try:
        with open(file_path, "wb") as output:
            output.write(image_bytes)
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail=f"Не удалось сохранить изображение манекена: {exc}"
        ) from exc

    relative_path = f"{user_id}/{location_segment}/{filename}"
    if MANNEQUIN_URL_PREFIX:
        return f"{MANNEQUIN_URL_PREFIX}/{relative_path}"

    return request.url_for("mannequins", path=relative_path)


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

    weather = (
        db.query(models.Weather).order_by(models.Weather.created_at.desc()).first()
    )
    prompt_parts = []
    for outfit in outfits:
        clothing_items = (
            db.query(models.Clothes)
            .filter(models.Clothes.id.in_(outfit.clothing_ids))
            .all()
        )
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
        raise HTTPException(
            status_code=404, detail="Недостаточно данных для рекомендаций"
        )

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
        raise HTTPException(
            status_code=502, detail=f"Не удалось получить рекомендации: {exc}"
        ) from exc

    message = response.choices[0].message.content if response.choices else None
    if not message:
        raise HTTPException(status_code=502, detail="AI вернул пустой ответ")

    return {"recommendation": message.strip()}


@router.get(
    "/mannequin/{user_id}/history", response_model=list[schemas.StoredMannequinResponse]
)
def get_mannequin_history(
    user_id: int,
    db: Session = Depends(get_db),
    limit: int = Query(10, ge=1, le=50),
    location_id: Optional[int] = Query(
        default=None, description="Фильтр по локации гардероба"
    ),
):
    query = db.query(models.MannequinImage).filter(
        models.MannequinImage.user_id == user_id
    )
    if location_id is not None:
        ensure_location_for_user(db, user_id, location_id)
        query = query.filter(models.MannequinImage.location_id == location_id)

    records = query.order_by(models.MannequinImage.created_at.desc()).limit(limit).all()

    history: list[schemas.StoredMannequinResponse] = []
    for record in records:
        raw_items = record.items if isinstance(record.items, list) else []
        mannequin_items: list[schemas.MannequinItem] = []
        for payload in raw_items:
            try:
                mannequin_items.append(schemas.MannequinItem.model_validate(payload))
            except Exception:
                continue

        weather_payload = record.weather if isinstance(record.weather, dict) else None
        weather_snapshot = None
        if weather_payload:
            try:
                weather_snapshot = schemas.WeatherSnapshot(**weather_payload)
            except Exception:
                weather_snapshot = None

        history.append(
            schemas.StoredMannequinResponse(
                id=record.id,
                user_id=record.user_id,
                image_url=record.image_url,
                location_id=record.location_id,
                created_at=record.created_at,
                items=mannequin_items,
                weather=weather_snapshot,
            )
        )

    return history


@router.get("/mannequin/{user_id}", response_model=schemas.MannequinResponse)
def generate_mannequin(
    user_id: int,
    request: Request,
    location_id: Optional[int] = Query(
        default=None, description="Выбор гардероба по локации"
    ),
    db: Session = Depends(get_db),
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    weather = (
        db.query(models.Weather).order_by(models.Weather.created_at.desc()).first()
    )
    if not weather:
        raise HTTPException(status_code=404, detail="Нет погодных данных")

    clothes_query = db.query(models.Clothes).filter(models.Clothes.user_id == user_id)
    if location_id is not None:
        ensure_location_for_user(db, user_id, location_id)
        clothes_query = clothes_query.filter(models.Clothes.location_id == location_id)

    clothes = clothes_query.all()
    if not clothes:
        raise HTTPException(status_code=404, detail="Одежда не найдена")

    selected_items = _select_outfit(clothes, weather)
    if not selected_items:
        raise HTTPException(
            status_code=404, detail="Не удалось подобрать одежду для манекена"
        )

    prompt = _build_mannequin_prompt(selected_items, weather, user.gender)

    try:
        image_response = client.images.generate(
            model="gpt-image-1",
            prompt=prompt,
            size="1024x1536",
            quality="high",
            n=1,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Не удалось сгенерировать изображение манекена: {exc}",
        ) from exc

    if not image_response.data:
        raise HTTPException(status_code=502, detail="AI не вернул изображение")

    location_segment = str(location_id) if location_id is not None else "shared"
    image_url = _save_mannequin_image(
        image_response.data[0].b64_json, user_id, location_segment, request
    )

    mannequin_record = models.MannequinImage(
        user_id=user_id,
        location_id=location_id,
        image_url=image_url,
        items=[item.model_dump() for item in selected_items],
        weather={
            "temperature": _coerce_int(weather.temperature),
            "humidity": _coerce_int(weather.humidity),
            "condition": weather.condition,
            "wind_speed": _coerce_int(weather.wind_speed),
        },
    )
    db.add(mannequin_record)
    db.commit()
    db.refresh(mannequin_record)

    return schemas.MannequinResponse(
        image_url=image_url,
        weather=schemas.WeatherSnapshot(
            temperature=_coerce_int(weather.temperature),
            humidity=_coerce_int(weather.humidity),
            condition=weather.condition,
            wind_speed=_coerce_int(weather.wind_speed),
        ),
        items=[schemas.MannequinItem.model_validate(item) for item in selected_items],
    )
