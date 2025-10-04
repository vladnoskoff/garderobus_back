import openai
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import models
from database import get_db
import settings
from datetime import datetime
from openai import OpenAI
import requests

router = APIRouter(prefix="/ai", tags=["AI Recommendations"])

openai.api_key = settings.OPENAI_API_KEY
client = OpenAI(api_key=("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"))

def get_season_from_temperature(temp_celsius: float) -> str:
    if temp_celsius >= 20:
        return "Лето"
    elif 10 <= temp_celsius < 20:
        return "Весна"
    elif 0 <= temp_celsius < 10:
        return "Осень"
    else:
        return "Зима"

@router.get("/recommendation/{user_id}")
def ai_recommendation(user_id: int, db: Session = Depends(get_db)):
    """Анализ истории нарядов и советы по улучшению"""
    outfits = db.query(models.Outfit).filter(models.Outfit.user_id == user_id).order_by(models.Outfit.created_at.desc()).limit(10).all()
    if not outfits:
        raise HTTPException(status_code=404, detail="История нарядов пуста")

    prompt = "Проанализируй мои наряды и предложи советы по улучшению (цвет, сезон, материалы):\n"
    for outfit in outfits:
        clothing_items = db.query(models.Clothes).filter(models.Clothes.id.in_(outfit.clothing_ids)).all()
        items_desc = [f"{item.name} ({item.category}, {item.color}, {item.material}, {item.season})" for item in clothing_items]
        prompt += f"- Наряд {outfit.id}: {', '.join(items_desc)}\n"

    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[
            {"role": "system", "content": "Ты эксперт по моде. Анализируй сочетание одежды по цвету, сезону и материалам."},
            {"role": "user", "content": prompt}
        ]
    )

    return {"recommendation": response["choices"][0]["message"]["content"]}


@router.get("/visual-recommendation/{user_id}")
def generate_visual_outfits(user_id: int, db: Session = Depends(get_db)):
    outfits = (
        db.query(models.Outfit)
        .filter(models.Outfit.user_id == user_id)
        .order_by(models.Outfit.created_at.desc())
        .limit(3)
        .all()
    )

    if not outfits:
        raise HTTPException(status_code=404, detail="Нет нарядов для визуализации")

    image_urls = []

    for outfit in outfits:
        if outfit.image_url:
            image_urls.append(outfit.image_url)
            continue

        clothing_items = db.query(models.Clothes).filter(models.Clothes.id.in_(outfit.clothing_ids)).all()
        if not clothing_items:
            continue

        prompt = (
            "Create a high-quality image of a mannequin in a neutral pose, wearing a weather-appropriate full outfit. "
            "This should reflect the following clothing items:\n"
        )
        for item in clothing_items:
            prompt += f"- A {item.color} {item.material or ''} {item.category.lower()} ({item.name})\n"

        try:
            response = openai.Image.create(
                prompt=prompt,
                n=1,
                size="512x512"
            )
            image_url = response["data"][0]["url"]
            outfit.image_url = image_url
            db.commit()
            image_urls.append(image_url)
        except Exception as e:
            print(f"Ошибка генерации изображения: {e}")
            continue

    if not image_urls:
        raise HTTPException(status_code=500, detail="Не удалось сгенерировать изображения")

    return {"images": image_urls}


@router.get("/generate-multiple/{user_id}/{city}")
def generate_multiple_outfits(user_id: int, city: str, db: Session = Depends(get_db)):
    """
    Генерирует 3 варианта нарядов по погоде и отображает визуализации.
    """
    weather = db.query(models.Weather).order_by(models.Weather.created_at.desc()).first()
    if not weather:
        raise HTTPException(status_code=404, detail="Нет погодных данных")

    current_season = get_season_from_temperature(weather.temperature)

    all_clothes = db.query(models.Clothes).filter(models.Clothes.user_id == user_id).all()
    if not all_clothes:
        raise HTTPException(status_code=404, detail="Одежда не найдена")

    outfits_data = []

    for i in range(3):
        selected = [c for c in all_clothes if c.season.lower() == current_season][:3]
        if not selected:
            continue

        outfit = models.Outfit(
            user_id=user_id,
            weather_id=weather.id,
            clothing_ids=[c.id for c in selected]
        )
        db.add(outfit)
        db.commit()
        db.refresh(outfit)

        prompt = (
            "Create a high-quality image of a mannequin in a neutral pose, wearing a weather-appropriate full outfit. "
            "This should reflect the following clothing items:\n"
        )
        for item in selected:
            prompt += f"- A {item.color} {item.material or ''} {item.category.lower()} ({item.name})\n"

        try:
            response = openai.Image.create(
                prompt=prompt,
                n=1,
                size="512x512"
            )
            image_url = response["data"][0]["url"]
            outfit.image_url = image_url
            db.commit()

            outfits_data.append({
                "outfit_id": outfit.id,
                "image_url": image_url
            })

        except Exception as e:
            print(f"Ошибка генерации изображения: {e}")
            continue

    if not outfits_data:
        raise HTTPException(status_code=500, detail="Не удалось сгенерировать наряды")

    return outfits_data

@router.get("/test-summer-look/{user_id}")
async def test_summer_outfit(user_id: int, db: Session = Depends(get_db)):
    """
    Генерация летнего наряда (температура +25°C) через ChatGPT (DALL-E).
    """
    # Создаем фиктивную погоду
    weather = models.Weather(
        temperature=25,
        humidity=40,
        condition="sunny",
        wind_speed=3,
        created_at=datetime.utcnow()
    )
    db.add(weather)
    db.commit()
    db.refresh(weather)

    # Получаем летнюю одежду пользователя
    summer_clothes = db.query(models.Clothes).filter(
        models.Clothes.user_id == user_id,
        models.Clothes.season.ilike("Лето")
    ).all()

    if not summer_clothes:
        raise HTTPException(status_code=404, detail="Нет летней одежды для пользователя")

    # Собираем описания одежды
    prompt_parts = [item.prompt_description for item in summer_clothes if item.prompt_description]
    if not prompt_parts:
        raise HTTPException(status_code=400, detail="Нет описаний для одежды")

    # Собираем итоговый промпт
    prompt = (
        "Create a high-quality image of a mannequin in a neutral standing pose, "
        "wearing the following summer outfit:\n" +
        "\n".join(f"- {desc}" for desc in prompt_parts)
    )

    # Создаем наряд в базе
    outfit = models.Outfit(
        user_id=user_id,
        weather_id=weather.id,
        clothing_ids=[c.id for c in summer_clothes]
    )
    db.add(outfit)
    db.commit()
    db.refresh(outfit)

    # Генерируем изображение через OpenAI DALL-E
    try:
        response = openai.Image.create(
            model="dall-e-3",  # Можно использовать dall-e-2 если хочешь быстрее
            prompt=prompt,
            n=1,
            size="1024x1024"
        )
        image_url = response["data"][0]["url"]
        outfit.image_url = image_url
        db.commit()

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка генерации изображения через DALL-E: {e}")

    return {
        "outfit_id": outfit.id,
        "image_url": image_url,
        "weather": {
            "temperature": weather.temperature,
            "condition": weather.condition
        },
        "clothes": [item.name for item in summer_clothes]
    }
    
    
    
    
    