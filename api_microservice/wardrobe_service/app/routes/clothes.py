import base64
import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional, Sequence
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from fastapi.encoders import jsonable_encoder
from pydantic import ValidationError
from sqlalchemy.orm import Session

from api_microservice.common import settings
from api_microservice.common.cache import (
    cache,
    invalidate_clothes_for_user,
    invalidate_outfit_history_for_user,
)
from api_microservice.common import models, schemas
from api_microservice.common.openai_client import get_openai_client

from ..database import get_db, get_read_db
from .location_utils import ensure_location_for_user

client = get_openai_client()
router = APIRouter(prefix="/clothes", tags=["Clothes"])

CLOTHES_UPLOAD_DIR = settings.CLOTHES_IMAGE_DIR
CLOTHES_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
CLOTHES_IMAGE_URL_PREFIX = settings.CLOTHES_IMAGE_URL_PREFIX.rstrip("/")


def _build_image_url(relative_path: str) -> str:
    if CLOTHES_IMAGE_URL_PREFIX:
        return f"{CLOTHES_IMAGE_URL_PREFIX}/{relative_path}"
    return f"/{relative_path}"


def _relative_image_path(image_url: Optional[str]) -> Optional[str]:
    if not image_url:
        return None
    prefix = CLOTHES_IMAGE_URL_PREFIX
    if prefix and image_url.startswith(f"{prefix}/"):
        return image_url[len(f"{prefix}/") :]
    if image_url.startswith("/"):
        return image_url.lstrip("/")
    return None


def _gallery_dir(user_id: int, location_segment: str, clothes_id: int) -> Path:
    return CLOTHES_UPLOAD_DIR / str(user_id) / location_segment / str(clothes_id)


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
            "maxItems": 2,
        },
        "style": {"type": "array", "items": {"type": "string"}},
        "occasions": {"type": "array", "items": {"type": "string"}},
        "care": {"type": ["string", "null"]},
        "tags": {"type": "array", "items": {"type": "string"}},
        "catalog_description": {"type": "string"},
        "gen_prompt": {"type": "string"},
        "pairing_hints": {"type": "array", "items": {"type": "string"}},
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
        "pairing_hints",
    ],
    "additionalProperties": False,
}

_AI_LANGUAGE_PROMPTS = {
    "ru": {
        "system": (
            "You are a fashion product analyst. Identify garment details strictly from the image. "
            "Return ONLY valid JSON that matches the provided JSON Schema. "
            "Populate every textual field in Russian language with natural wording."
        ),
        "user": (
            "Проанализируй одежду, заполни все текстовые поля исключительно на русском языке и верни JSON по схеме. "
            "Сформируй лаконичное описание и нейтральный промпт для манекена."
        ),
    },
    "en": {
        "system": (
            "You are a fashion product analyst. Identify garment details strictly from the image. "
            "Return ONLY valid JSON that matches the provided JSON Schema. "
            "Populate every textual field in English with natural, idiomatic wording."
        ),
        "user": (
            "Analyse the garment, fill in every text field exclusively in English and return JSON that matches the schema. "
            "Provide a concise catalogue description and a neutral mannequin prompt."
        ),
    },
}


def _normalize_language_code(value: Optional[str]) -> str:
    if value is None:
        return "ru"

    normalized = value.strip().lower()
    if not normalized:
        return "ru"

    if normalized in _AI_LANGUAGE_PROMPTS:
        return normalized

    raise HTTPException(
        status_code=400,
        detail=(
            "Неподдерживаемый язык анализа. Допустимые значения: "
            f"{', '.join(sorted(_AI_LANGUAGE_PROMPTS))}"
        ),
    )


@router.get("/user/{user_id}", response_model=list[schemas.ClothesResponse])
def get_user_clothes(
    user_id: int,
    location_id: Optional[int] = Query(
        default=None, description="Фильтр по локации гардероба"
    ),
    db: Session = Depends(get_read_db),
):
    query = db.query(models.Clothes).filter(models.Clothes.user_id == user_id)
    location_segment = "location:all"
    if location_id is not None:
        ensure_location_for_user(db, user_id, location_id)
        query = query.filter(models.Clothes.location_id == location_id)
        location_segment = f"location:{location_id}"

    key = cache.make_key("clothes", user_id, location_segment)
    cached = cache.get_json(key, resource="clothes")
    if cached is not None:
        return cached

    clothes_items = query.all()
    cache.set_json(
        key,
        jsonable_encoder(clothes_items),
        ttl=settings.CACHE_TTL_CLOTHES,
        resource="clothes",
    )
    return clothes_items


def _build_ai_messages(
    image_payload: str, is_base64: bool, language_code: str
) -> list[dict]:
    prompts = _AI_LANGUAGE_PROMPTS[language_code]
    if is_base64:
        image_content = {
            "type": "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{image_payload}"},
        }
    else:
        image_content = {"type": "image_url", "image_url": {"url": image_payload}}

    return [
        {
            "role": "system",
            "content": prompts["system"],
        },
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": prompts["user"],
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
            "json_schema": {
                "name": "ClothesInsights",
                "schema": AI_JSON_SCHEMA,
                "strict": True,
            },
        },
        temperature=0.2,
    )

    choice = response.choices[0].message if response.choices else None
    if not choice or not choice.content:
        raise HTTPException(status_code=502, detail="AI returned an empty response")

    return choice.content


async def _analyze_image_bytes(
    image_bytes_list: Sequence[bytes], language_code: str
) -> schemas.ClothesInsights:
    payloads = []
    for blob in image_bytes_list:
        if not blob:
            continue
        payloads.append(base64.b64encode(blob).decode("utf-8"))

    if not payloads:
        raise HTTPException(status_code=400, detail="Пустой файл изображения")

    try:
        raw_response = _call_ai_for_insights(
            _build_ai_messages(payloads, True, language_code)
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=502, detail=f"Не удалось получить анализ изображения: {exc}"
        ) from exc

    try:
        return schemas.ClothesInsights.model_validate_json(raw_response)
    except ValidationError as exc:
        raise HTTPException(
            status_code=502,
            detail={"error": "Некорректный формат ответа ИИ", "details": exc.errors()},
        ) from exc


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
        care_instructions=insights.care.strip() if insights.care else None,
        ai_metadata=insights,
        temperature_min=temp_min,
        temperature_max=temp_max,
    )


@router.post("/autofill", response_model=schemas.ClothesAutoFill)
async def autofill_clothes_fields(
    file: UploadFile = File(...), language_code: str = Form("ru")
):
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Файл изображения пустой")
    normalized_language = _normalize_language_code(language_code)
    insights = await _analyze_image_bytes(image_bytes, normalized_language)
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
    care_instructions: Optional[str] = Form(None),
    temperature_min: Optional[int] = Form(None),
    temperature_max: Optional[int] = Form(None),
    ai_metadata: Optional[str] = Form(None),
    auto_fill: bool = Form(False),
    location_id: Optional[int] = Form(None),
    language_code: Optional[str] = Form(None),
    files: list[UploadFile] = File(...),
    db: Session = Depends(get_db),
):
    """Добавление одежды с возможностью автозаполнения полей через AI и поддержкой галереи изображений."""

    uploads: list[tuple[UploadFile, bytes]] = []
    for upload in files:
        try:
            content = await upload.read()
        except Exception as exc:
            raise HTTPException(
                status_code=400, detail=f"Не удалось прочитать файл: {exc}"
            ) from exc
        if not content:
            continue
        uploads.append((upload, content))

    if not uploads:
        raise HTTPException(status_code=400, detail="Файлы изображений отсутствуют")

    if location_id is not None:
        ensure_location_for_user(db, user_id, location_id)

    image_payloads = [content for _, content in uploads]

    normalized_language = _normalize_language_code(language_code)

    autofilled_metadata: Optional[schemas.ClothesAutoFill] = None
    if auto_fill or not all([name, category, season, color]):
        insights = await _analyze_image_bytes(image_payloads, normalized_language)
        autofilled_metadata = _insights_to_autofill(insights)

        def _merge_field(
            current: Optional[str], generated: Optional[str]
        ) -> Optional[str]:
            if auto_fill:
                return generated or current
            return current or generated

        name = _merge_field(name, autofilled_metadata.name)
        category = _merge_field(category, autofilled_metadata.category)
        season = _merge_field(season, autofilled_metadata.season)
        color = _merge_field(color, autofilled_metadata.color)
        material = _merge_field(material, autofilled_metadata.material)
        prompt_description = _merge_field(
            prompt_description, autofilled_metadata.prompt_description
        )
        care_instructions = _merge_field(
            care_instructions, autofilled_metadata.care_instructions
        )

        def _merge_temperature(
            current: Optional[int], generated: Optional[int]
        ) -> Optional[int]:
            if generated is None:
                return current
            if auto_fill or current is None:
                return generated
            return current

        temperature_min = _merge_temperature(
            temperature_min, autofilled_metadata.temperature_min
        )
        temperature_max = _merge_temperature(
            temperature_max, autofilled_metadata.temperature_max
        )

        if autofilled_metadata.ai_metadata:
            ai_metadata = autofilled_metadata.ai_metadata.model_dump_json()

    if not all([name, category, season, color]):
        raise HTTPException(
            status_code=422, detail="Не удалось определить обязательные поля одежды"
        )

    metadata_payload = None
    if ai_metadata:
        try:
            if autofilled_metadata and isinstance(ai_metadata, str):
                metadata_payload = autofilled_metadata.ai_metadata.model_dump()
            else:
                metadata_payload = schemas.ClothesInsights.model_validate_json(
                    ai_metadata
                ).model_dump()
        except Exception:
            metadata_payload = None

    if metadata_payload is None:
        metadata_payload = {}

    temp_range = (
        metadata_payload.get("temp_c_range")
        if isinstance(metadata_payload, dict)
        else None
    )
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
            pass

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
        prompt_description=prompt_description or "",
        care_instructions=care_instructions,
        location_id=location_id,
    )

    if metadata_payload:
        new_clothes.ai_metadata = metadata_payload

    db.add(new_clothes)
    db.flush()

    location_segment = str(location_id) if location_id is not None else "shared"
    destination_dir = _gallery_dir(user_id, location_segment, new_clothes.id)

    saved_files: list[tuple[str, bool]] = []
    try:
        destination_dir.mkdir(parents=True, exist_ok=True)
        for index, (upload, content) in enumerate(uploads, start=1):
            suffix = Path(upload.filename or "item.jpg").suffix
            if not suffix:
                suffix = ".jpg"
            unique_name = f"{index:02d}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid4().hex}{suffix}"
            save_path = destination_dir / unique_name
            with open(save_path, "wb") as buffer:
                buffer.write(content)
            relative_path = (
                f"{user_id}/{location_segment}/{new_clothes.id}/{unique_name}"
            )
            image_url = _build_image_url(relative_path)
            saved_files.append((image_url, index == 1))
    except Exception as exc:
        shutil.rmtree(destination_dir, ignore_errors=True)
        db.rollback()
        raise HTTPException(
            status_code=500, detail=f"Не удалось сохранить изображение: {exc}"
        ) from exc

    if not saved_files:
        shutil.rmtree(destination_dir, ignore_errors=True)
        db.rollback()
        raise HTTPException(status_code=500, detail="Не удалось сохранить изображения")

    new_clothes.image_url = saved_files[0][0]
    for image_url, is_primary in saved_files:
        db.add(
            models.ClothesImage(
                clothes_id=new_clothes.id,
                image_url=image_url,
                is_primary=is_primary,
            )
        )

    try:
        db.commit()
    except Exception:
        db.rollback()
        shutil.rmtree(destination_dir, ignore_errors=True)
        raise

    db.refresh(new_clothes)
    invalidate_clothes_for_user(new_clothes.user_id)
    invalidate_outfit_history_for_user(new_clothes.user_id)
    return new_clothes


@router.patch("/{clothes_id}", response_model=schemas.ClothesResponse)
def update_clothes(
    clothes_id: int,
    payload: schemas.ClothesUpdate,
    db: Session = Depends(get_db),
):
    clothes = db.query(models.Clothes).filter(models.Clothes.id == clothes_id).first()
    if not clothes:
        raise HTTPException(status_code=404, detail="Одежда не найдена")

    if payload.location_id is not None and payload.location_id != clothes.location_id:
        ensure_location_for_user(db, clothes.user_id, payload.location_id)
        old_segment = (
            str(clothes.location_id) if clothes.location_id is not None else "shared"
        )
        new_segment = (
            str(payload.location_id) if payload.location_id is not None else "shared"
        )
        if new_segment != old_segment:
            source_dir = _gallery_dir(clothes.user_id, old_segment, clothes.id)
            destination_dir = _gallery_dir(clothes.user_id, new_segment, clothes.id)
            if source_dir.exists():
                destination_dir.parent.mkdir(parents=True, exist_ok=True)
                if destination_dir.exists():
                    shutil.rmtree(destination_dir, ignore_errors=True)
                try:
                    shutil.move(str(source_dir), str(destination_dir))
                except Exception as exc:
                    raise HTTPException(
                        status_code=500,
                        detail=f"Не удалось перенести изображения одежды: {exc}",
                    ) from exc
                for image in clothes.images:
                    relative = _relative_image_path(image.image_url)
                    if not relative:
                        continue
                    filename = Path(relative).name
                    new_relative = (
                        f"{clothes.user_id}/{new_segment}/{clothes.id}/{filename}"
                    )
                    image.image_url = _build_image_url(new_relative)
                cover_relative = _relative_image_path(clothes.image_url)
                if cover_relative:
                    filename = Path(cover_relative).name
                    clothes.image_url = _build_image_url(
                        f"{clothes.user_id}/{new_segment}/{clothes.id}/{filename}"
                    )
        clothes.location_id = payload.location_id

    simple_fields = (
        "name",
        "category",
        "season",
        "color",
        "material",
        "prompt_description",
        "care_instructions",
    )
    for field in simple_fields:
        value = getattr(payload, field)
        if value is not None:
            setattr(clothes, field, value)

    metadata_payload = dict(clothes.ai_metadata or {})
    metadata_updated = False

    if payload.ai_metadata is not None:
        metadata_payload = dict(payload.ai_metadata)
        metadata_updated = True

    manual_range: list[int] = []
    if payload.temperature_min is not None:
        try:
            manual_range.append(int(payload.temperature_min))
        except (TypeError, ValueError):
            pass
    if payload.temperature_max is not None:
        try:
            manual_range.append(int(payload.temperature_max))
        except (TypeError, ValueError):
            pass

    if manual_range:
        metadata_updated = True
        manual_range.sort()
        if len(manual_range) == 1:
            metadata_payload["temp_c_range"] = [manual_range[0]]
        else:
            metadata_payload["temp_c_range"] = [manual_range[0], manual_range[-1]]

    if metadata_updated:
        if metadata_payload:
            clothes.ai_metadata = metadata_payload
        else:
            clothes.ai_metadata = None

    db.commit()
    db.refresh(clothes)
    invalidate_clothes_for_user(clothes.user_id)
    invalidate_outfit_history_for_user(clothes.user_id)
    return clothes


@router.get("/", response_model=list[schemas.ClothesResponse])
def get_all_clothes(db: Session = Depends(get_read_db)):
    return db.query(models.Clothes).all()


@router.get("/{clothes_id}", response_model=schemas.ClothesResponse)
def get_clothes(clothes_id: int, db: Session = Depends(get_read_db)):
    clothes = db.query(models.Clothes).filter(models.Clothes.id == clothes_id).first()
    if not clothes:
        raise HTTPException(status_code=404, detail="Одежда не найдена")
    return clothes


@router.delete("/{clothes_id}")
def delete_clothes(clothes_id: int, db: Session = Depends(get_db)):
    clothes = db.query(models.Clothes).filter(models.Clothes.id == clothes_id).first()
    if not clothes:
        raise HTTPException(status_code=404, detail="Одежда не найдена")

    location_segment = (
        str(clothes.location_id) if clothes.location_id is not None else "shared"
    )
    gallery_dir = _gallery_dir(clothes.user_id, location_segment, clothes.id)
    shutil.rmtree(gallery_dir, ignore_errors=True)
    db.delete(clothes)
    db.commit()
    invalidate_clothes_for_user(clothes.user_id)
    invalidate_outfit_history_for_user(clothes.user_id)
    return {"message": "Одежда удалена"}
