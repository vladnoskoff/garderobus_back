import base64
from datetime import datetime
from pathlib import Path
from typing import Iterable, List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models
import schemas
import settings
from database import get_db
from openai import OpenAI

router = APIRouter(prefix="/ai", tags=["AI Recommendations"])

client = OpenAI(api_key=settings.OPENAI_API_KEYY)

BASE_DIR = Path(__file__).resolve().parent.parent
MANNEQUIN_DIR = BASE_DIR / "mannequins"
MANNEQUIN_DIR.mkdir(parents=True, exist_ok=True)


def get_season_from_temperature(temp_celsius: float) -> str:
    if temp_celsius >= 20:
        return "Лето"
    if 10 <= temp_celsius < 20:
        return "Весна"
    if 0 <= temp_celsius < 10:
        return "Осень"
    return "Зима"


def _filter_by_season(clothes: Iterable[models.Clothes], season: str) -> List[models.Clothes]:
    normalized = season.lower()
    return [item for item in clothes if item.season and normalized in item.season.lower()]


def _select_outfit(clothes: List[models.Clothes], temperature: float) -> List[models.Clothes]:
    season = get_season_from_temperature(temperature)
    seasonal_items = _filter_by_season(clothes, season) or clothes

    selected: List[models.Clothes] = []
    used_categories: set[str] = set()

    for item in seasonal_items:
        category_key = (item.category or "").lower()
        if category_key in used_categories:
            continue
        selected.append(item)
        used_categories.add(category_key)
        if len(selected) >= 4:
            break

    if len(selected) < 3:
        for item in seasonal_items:
            if item not in selected:
                selected.append(item)
            if len(selected) >= 3:
                break

    return selected


def _build_mannequin_prompt(items: List[models.Clothes], weather: models.Weather) -> str:
    lines = [
        "Create a hyperrealistic studio photograph of a faceless mannequin wearing a cohesive outfit.",
        "Use soft neutral lighting, clean white background, no logos or text.",
        f"Weather context: {weather.condition}, {weather.temperature}°C, humidity {weather.humidity}%, wind {weather.wind_speed or 0} m/s.",
        "The outfit must be comfortable for the described weather conditions and feel stylish and contemporary.",
        "Clothing items to include:",
    ]

    for item in items:
        base_description = item.prompt_description or f"{item.color} {item.category}"
        lines.append(f"- {base_description.strip()} (season: {item.season})")

    lines.append("Ensure the overall look is balanced and colour-coordinated.")
    return "\n".join(lines)


def _save_mannequin_image(image_b64: str, user_id: int) -> str:
    filename = f"mannequin_{user_id}_{datetime.now().strftime('%Y%m%d%H%M%S')}.png"
    file_path = MANNEQUIN_DIR / filename
    image_bytes = base64.b64decode(image_b64)
    with open(file_path, "wb") as output:
        output.write(image_bytes)
    return f"/mannequins/{filename}"


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

    prompt_parts = []
    for outfit in outfits:
        clothing_items = db.query(models.Clothes).filter(models.Clothes.id.in_(outfit.clothing_ids)).all()
        if not clothing_items:
            continue
        formatted_items = ", ".join(
            f"{item.name} ({item.category}, {item.color}, {item.material or 'материал не указан'}, сезон: {item.season})"
            for item in clothing_items
        )
        prompt_parts.append(f"Наряд #{outfit.id}: {formatted_items}")

    if not prompt_parts:
        raise HTTPException(status_code=404, detail="Недостаточно данных для рекомендаций")

    prompt = (
        "Проанализируй мои недавние наряды и предложи, как улучшить стиль, сочетания цветов и материалов. "
        "Дай практичные советы, учитывая погоду и повседневные ситуации.\n" + "\n".join(prompt_parts)
    )

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": "Ты модный стилист. Дай структурированные советы с акцентом на комфорт и актуальные тренды.",
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

    selected_items = _select_outfit(clothes, weather.temperature)
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
