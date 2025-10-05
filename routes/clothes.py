from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from datetime import datetime
from pathlib import Path
from uuid import uuid4
from typing import Optional

import base64

from pydantic import ValidationError

import models
from database import get_db
import settings
import schemas
from openai import OpenAI

client = OpenAI(api_key=settings.OPENAI_API_KEYY)
router = APIRouter(prefix="/clothes", tags=["Clothes"])

BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "clothes_images"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

AI_JSON_SCHEMA = {
    "type": "object",
    "properties": {
        "title": {"type": "string"},
        "category": {"type": "string"},
        "gender": {"type": ["string", "null"]},
        "colors": {"type": "array", "items": {"type": "string"}},
        "pattern": {"type": ["string", "null"]},
        "material": {"type": ["string", "null"]},
        "fit": {"type": ["string", "null"]},
        "season": {"type": "array", "items": {"type": "string"}},
        "temp_c_range": {
            "type": "array",
            "items": {"type": "integer"},
            "minItems": 2,
            "maxItems": 2
        },
        "style": {"type": "array", "items": {"type": "string"}},
        "occasions": {"type": "array", "items": {"type": "string"}},
        "care": {"type": ["string", "null"]},
        "tags": {"type": "array", "items": {"type": "string"}},
        "catalog_description": {"type": "string"},
        "gen_prompt": {"type": "string"},
        "pairing_hints": {"type": "array", "items": {"type": "string"}}
    },
    "required": [
        "title",
        "category",
        "gender",
        "colors",
        "pattern",
        "material",
        "fit",
        "season",
        "temp_c_range",
        "style",
        "occasions",
        "care",
        "tags",
        "catalog_description",
        "gen_prompt",
        "pairing_hints"
    ],
    "additionalProperties": False
}

@router.get("/user/{user_id}", response_model=list[schemas.ClothesResponse])
def get_user_clothes(user_id: int, db: Session = Depends(get_db)):
    return db.query(models.Clothes).filter(models.Clothes.user_id == user_id).all()
    
def _build_ai_messages(image_payload: str, is_base64: bool) -> list[dict]:
    if is_base64:
        image_content = {
            "type": "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{image_payload}"}
        }
    else:
        image_content = {
            "type": "image_url",
            "image_url": {"url": image_payload}
        }

    return [
        {
            "role": "system",
            "content": (
                "You are a fashion product analyst. Identify garment details strictly from the image. "
                "Return ONLY valid JSON that matches the provided JSON Schema."
            ),
        },
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": (
                        "Проанализируй одежду и верни JSON по схеме. Сформируй лаконичное описание и нейтральный промпт для манекена."
                    ),
                },
                image_content,
            ],
        },
    ]


def _call_ai_for_insights(messages: list[dict]) -> str:
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=messages,
        response_format={
            "type": "json_schema",
            "json_schema": {"name": "ClothesInsights", "schema": AI_JSON_SCHEMA, "strict": True},
        },
        temperature=0.2,
    )

    choice = response.choices[0].message if response.choices else None
    if not choice or not choice.content:
        raise HTTPException(status_code=502, detail="AI returned an empty response")

    return choice.content


async def _analyze_image_bytes(image_bytes: bytes) -> schemas.ClothesInsights:
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Пустой файл изображения")

    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    try:
        raw_response = _call_ai_for_insights(_build_ai_messages(image_b64, True))
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Не удалось получить анализ изображения: {exc}") from exc

    try:
        return schemas.ClothesInsights.model_validate_json(raw_response)
    except ValidationError as exc:
        raise HTTPException(status_code=502, detail={"error": "Некорректный формат ответа ИИ", "details": exc.errors()}) from exc


def _insights_to_autofill(insights: schemas.ClothesInsights) -> schemas.ClothesAutoFill:
    primary_season = insights.season[0] if insights.season else "Универсальная"
    primary_color = ", ".join(insights.colors) if insights.colors else "Неопределённый"
    description = insights.catalog_description.strip()

    return schemas.ClothesAutoFill(
        name=insights.title.strip(),
        category=insights.category.strip(),
        season=primary_season.strip(),
        color=primary_color.strip(),
        material=insights.material.strip() if insights.material else None,
        prompt_description=description,
        ai_metadata=insights,
    )

@router.post("/autofill", response_model=schemas.ClothesAutoFill)
async def autofill_clothes_fields(file: UploadFile = File(...)):
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Файл изображения пустой")
    insights = await _analyze_image_bytes(image_bytes)
    return _insights_to_autofill(insights)


@router.post("/", response_model=schemas.ClothesResponse)
async def add_clothes(
    user_id: int = Form(...),
    name: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    season: Optional[str] = Form(None),
    color: Optional[str] = Form(None),
    material: Optional[str] = Form(None),
    prompt_description: Optional[str] = Form(None),
    auto_fill: bool = Form(False),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """Добавление одежды с возможностью автозаполнения полей через AI."""

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Файл изображения пустой")
    if auto_fill or not all([name, category, season, color]):
        insights = await _analyze_image_bytes(image_bytes)
        auto_data = _insights_to_autofill(insights)
        name = name or auto_data.name
        category = category or auto_data.category
        season = season or auto_data.season
        color = color or auto_data.color
        material = material or auto_data.material
        prompt_description = prompt_description or auto_data.prompt_description

    if not all([name, category, season, color]):
        raise HTTPException(status_code=422, detail="Не удалось определить обязательные поля одежды")

    file_extension = Path(file.filename or "item.jpg").suffix
    unique_name = f"{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid4().hex}{file_extension}"
    save_path = UPLOAD_DIR / unique_name

    try:
        with open(save_path, "wb") as buffer:
            buffer.write(image_bytes)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Не удалось сохранить изображение: {exc}") from exc

    image_url = f"/clothes_images/{unique_name}"

    new_clothes = models.Clothes(
        user_id=user_id,
        name=name,
        category=category,
        season=season,
        color=color,
        material=material,
        image_url=image_url,
        prompt_description=prompt_description or ""
    )

    db.add(new_clothes)
    db.commit()
    db.refresh(new_clothes)
    return new_clothes

@router.get("/", response_model=list[schemas.ClothesResponse])
def get_all_clothes(db: Session = Depends(get_db)):
    return db.query(models.Clothes).all()

@router.get("/{clothes_id}", response_model=schemas.ClothesResponse)
def get_clothes(clothes_id: int, db: Session = Depends(get_db)):
    clothes = db.query(models.Clothes).filter(models.Clothes.id == clothes_id).first()
    if not clothes:
        raise HTTPException(status_code=404, detail="Одежда не найдена")
    return clothes

@router.delete("/{clothes_id}")
def delete_clothes(clothes_id: int, db: Session = Depends(get_db)):
    clothes = db.query(models.Clothes).filter(models.Clothes.id == clothes_id).first()
    if not clothes:
        raise HTTPException(status_code=404, detail="Одежда не найдена")
    db.delete(clothes)
    db.commit()
    return {"message": "Одежда удалена"}
