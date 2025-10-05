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
import schemas
import settings
from openai_client import get_openai_client

client = get_openai_client()
router = APIRouter(prefix="/clothes", tags=["Clothes"])

CLOTHES_UPLOAD_DIR = settings.CLOTHES_IMAGE_DIR
CLOTHES_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
CLOTHES_IMAGE_URL_PREFIX = settings.CLOTHES_IMAGE_URL_PREFIX.rstrip("/")

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
    temp_min, temp_max = None, None
    if insights.temp_c_range:
        if len(insights.temp_c_range) == 2:
            temp_min, temp_max = insights.temp_c_range
        elif len(insights.temp_c_range) == 1:
            temp_min = insights.temp_c_range[0]

    return schemas.ClothesAutoFill(
        name=insights.title.strip(),
        category=insights.category.strip(),
        season=primary_season.strip(),
        color=primary_color.strip(),
        material=insights.material.strip() if insights.material else None,
        prompt_description=description,
        ai_metadata=insights,
        temperature_min=temp_min,
        temperature_max=temp_max,
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
    temperature_min: Optional[int] = Form(None),
    temperature_max: Optional[int] = Form(None),
    ai_metadata: Optional[str] = Form(None),
    auto_fill: bool = Form(False),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """Добавление одежды с возможностью автозаполнения полей через AI."""

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Файл изображения пустой")
    autofilled_metadata: Optional[schemas.ClothesAutoFill] = None
    if auto_fill or not all([name, category, season, color]):
        insights = await _analyze_image_bytes(image_bytes)
        autofilled_metadata = _insights_to_autofill(insights)
        def _merge_field(current: Optional[str], generated: Optional[str]) -> Optional[str]:
            if auto_fill:
                return generated or current
            return current or generated

        name = _merge_field(name, autofilled_metadata.name)
        category = _merge_field(category, autofilled_metadata.category)
        season = _merge_field(season, autofilled_metadata.season)
        color = _merge_field(color, autofilled_metadata.color)
        material = _merge_field(material, autofilled_metadata.material)
        prompt_description = _merge_field(prompt_description, autofilled_metadata.prompt_description)

        def _merge_temperature(current: Optional[int], generated: Optional[int]) -> Optional[int]:
            if generated is None:
                return current
            if auto_fill or current is None:
                return generated
            return current

        temperature_min = _merge_temperature(temperature_min, autofilled_metadata.temperature_min)
        temperature_max = _merge_temperature(temperature_max, autofilled_metadata.temperature_max)

        if autofilled_metadata.ai_metadata:
            ai_metadata = autofilled_metadata.ai_metadata.model_dump_json()

    if not all([name, category, season, color]):
        raise HTTPException(status_code=422, detail="Не удалось определить обязательные поля одежды")

    file_extension = Path(file.filename or "item.jpg").suffix
    unique_name = f"{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid4().hex}{file_extension}"
    save_path = CLOTHES_UPLOAD_DIR / unique_name

    try:
        with open(save_path, "wb") as buffer:
            buffer.write(image_bytes)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Не удалось сохранить изображение: {exc}") from exc

    if CLOTHES_IMAGE_URL_PREFIX:
        image_url = f"{CLOTHES_IMAGE_URL_PREFIX}/{unique_name}"
    else:
        image_url = f"/{unique_name}"

    metadata_payload = None
    if ai_metadata:
        try:
            if autofilled_metadata and isinstance(ai_metadata, str):
                metadata_payload = autofilled_metadata.ai_metadata.model_dump()
            else:
                metadata_payload = schemas.ClothesInsights.model_validate_json(ai_metadata).model_dump()
        except Exception:
            metadata_payload = None

    if metadata_payload is None:
        metadata_payload = {}

    temp_range = metadata_payload.get("temp_c_range") if isinstance(metadata_payload, dict) else None
    if isinstance(temp_range, (list, tuple)) and temp_range:
        try:
            if len(temp_range) >= 2:
                if temperature_min is None:
                    temperature_min = int(temp_range[0])
                if temperature_max is None:
                    temperature_max = int(temp_range[1])
            elif len(temp_range) == 1:
                single_temp = int(temp_range[0])
                if temperature_min is None:
                    temperature_min = single_temp
                if temperature_max is None:
                    temperature_max = single_temp
        except (TypeError, ValueError):
            temperature_min = temperature_min

    manual_range: list[int] = []
    for value in (temperature_min, temperature_max):
        if value is None:
            continue
        try:
            manual_range.append(int(value))
        except (TypeError, ValueError):
            continue

    if manual_range:
        manual_range.sort()
        if len(manual_range) == 1:
            metadata_payload["temp_c_range"] = [manual_range[0]]
        else:
            metadata_payload["temp_c_range"] = [manual_range[0], manual_range[-1]]

    if not metadata_payload:
        metadata_payload = None

    new_clothes = models.Clothes(
        user_id=user_id,
        name=name,
        category=category,
        season=season,
        color=color,
        material=material,
        image_url=image_url,
        prompt_description=prompt_description or "",
    )

    if metadata_payload:
        new_clothes.ai_metadata = metadata_payload

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
