"""Celery tasks that execute long-running AI powered workflows."""

from __future__ import annotations

import json
import logging
from time import perf_counter
from typing import Any, Callable, Dict, List, Optional

from prometheus_client import Counter, Histogram
from sqlalchemy.orm import joinedload

import observability
from celery_app import celery_app
from database import db_session
import models
import schemas
from openai_client import get_openai_client
from services.ai import (
    build_mannequin_prompt,
    coerce_int,
    extract_temp_range,
    save_mannequin_image,
    select_outfit,
)

log = logging.getLogger(__name__)

TASK_STARTED = Counter(
    "garderobus_tasks_started_total",
    "Total number of asynchronous jobs started.",
    ["task"],
)
TASK_COMPLETED = Counter(
    "garderobus_tasks_completed_total",
    "Total number of asynchronous jobs completed, labelled by outcome.",
    ["task", "outcome"],
)
TASK_DURATION = Histogram(
    "garderobus_task_duration_seconds",
    "Duration of asynchronous jobs in seconds.",
    ["task"],
)

JSON_SCHEMA: Dict[str, Any] = {
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


class TaskError(Exception):
    """Exception raised for business-level task failures that shouldn't retry."""

    def __init__(self, detail: str, status_code: int = 400) -> None:
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code

    def to_dict(self) -> Dict[str, Any]:
        return {"status": "error", "status_code": self.status_code, "detail": self.detail}


def _run_with_metrics(task_name: str, func: Callable[[], Dict[str, Any]]) -> Dict[str, Any]:
    TASK_STARTED.labels(task_name).inc()
    started = perf_counter()
    try:
        result = func()
    except TaskError as exc:  # expected domain failure
        TASK_COMPLETED.labels(task_name, "error").inc()
        elapsed = perf_counter() - started
        TASK_DURATION.labels(task_name).observe(elapsed)
        observability.observe_celery_latency(task_name, elapsed)
        return exc.to_dict()
    except Exception:  # pragma: no cover - unexpected failures should retry
        TASK_COMPLETED.labels(task_name, "failure").inc()
        elapsed = perf_counter() - started
        TASK_DURATION.labels(task_name).observe(elapsed)
        observability.observe_celery_latency(task_name, elapsed)
        log.exception("Task %s failed with unexpected error", task_name)
        raise
    else:
        TASK_COMPLETED.labels(task_name, "success").inc()
        elapsed = perf_counter() - started
        TASK_DURATION.labels(task_name).observe(elapsed)
        observability.observe_celery_latency(task_name, elapsed)
        return {"status": "success", "result": result}


def _load_user(user_id: int) -> models.User:
    with db_session() as session:
        user = session.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            raise TaskError("Пользователь не найден", status_code=404)
        session.expunge(user)
        return user


def _load_latest_weather() -> models.Weather:
    with db_session(read_only=True) as session:
        weather = (
            session.query(models.Weather)
            .order_by(models.Weather.created_at.desc())
            .first()
        )
        if not weather:
            raise TaskError("Нет погодных данных", status_code=404)
        session.expunge(weather)
        return weather


def _load_recent_outfits(user_id: int) -> List[models.Outfit]:
    with db_session(read_only=True) as session:
        outfits = (
            session.query(models.Outfit)
            .filter(models.Outfit.user_id == user_id)
            .order_by(models.Outfit.created_at.desc())
            .limit(10)
            .all()
        )
        if not outfits:
            raise TaskError("История нарядов пуста", status_code=404)
        for outfit in outfits:
            session.expunge(outfit)
        return outfits


def _load_clothes(user_id: int, location_id: Optional[int]) -> List[models.Clothes]:
    with db_session(read_only=True) as session:
        query = (
            session.query(models.Clothes)
            .options(
                joinedload(models.Clothes.location),
                joinedload(models.Clothes.metadata_entry),
            )
            .filter(models.Clothes.user_id == user_id)
        )
        if location_id is not None:
            location = (
                session.query(models.WardrobeLocation)
                .filter(
                    models.WardrobeLocation.id == location_id,
                    models.WardrobeLocation.user_id == user_id,
                )
                .first()
            )
            if not location:
                raise TaskError("Локация не найдена для пользователя", status_code=404)
            query = query.filter(models.Clothes.location_id == location_id)

        clothes = query.all()
        if not clothes:
            raise TaskError("Одежда не найдена", status_code=404)
        for item in clothes:
            # Access related data before expunging to avoid detached lazy loads.
            if item.metadata_entry is not None:
                _ = item.metadata_entry.data
            session.expunge(item)
        return clothes


@celery_app.task(
    bind=True,
    name="ai.generate_recommendation",
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_jitter=True,
    retry_kwargs={"max_retries": 3},
)
def generate_recommendation_task(self, user_id: int) -> Dict[str, Any]:
    client = get_openai_client()

    def _impl() -> Dict[str, Any]:
        outfits = _load_recent_outfits(user_id)
        weather = _load_latest_weather()

        prompt_parts: List[str] = []
        with db_session(read_only=True) as session:
            for outfit in outfits:
                clothing_items = (
                    session.query(models.Clothes)
                    .filter(models.Clothes.id.in_(outfit.clothing_ids))
                    .all()
                )
                if not clothing_items:
                    continue
                formatted_items: List[str] = []
                for item in clothing_items:
                    temp_min, temp_max = extract_temp_range(item)
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
                if formatted_items:
                    prompt_parts.append(f"Наряд #{outfit.id}: " + "; ".join(formatted_items))

        if not prompt_parts:
            raise TaskError("Недостаточно данных для рекомендаций", status_code=404)

        weather_context = (
            f"Актуальная погода: {weather.temperature}°C, влажность {weather.humidity}%, ветер {weather.wind_speed or 0} м/с, условие: {weather.condition}."
        )

        prompt = (
            "Проанализируй мои последние наряды и предложи, как улучшить стиль, сочетания цветов и материалов. "
            "Дай практичные советы с учётом погодных условий и образа жизни. "
            "Ответь по-русски, структурируй рекомендации в виде списков.\n"
            + weather_context
            + "\n"
            + "\n".join(prompt_parts)
        )

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

        message = response.choices[0].message.content if response.choices else None
        if not message:
            raise TaskError("AI вернул пустой ответ", status_code=502)

        return {"recommendation": message.strip()}

    return _run_with_metrics("ai.generate_recommendation", _impl)


@celery_app.task(
    bind=True,
    name="ai.generate_mannequin",
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_jitter=True,
    retry_kwargs={"max_retries": 3},
)
def generate_mannequin_task(
    self,
    user_id: int,
    location_id: Optional[int] = None,
) -> Dict[str, Any]:
    client = get_openai_client()

    def _impl() -> Dict[str, Any]:
        user = _load_user(user_id)
        weather = _load_latest_weather()
        clothes = _load_clothes(user_id, location_id)

        selected_items = select_outfit(clothes, weather)
        if not selected_items:
            raise TaskError("Не удалось подобрать одежду для манекена", status_code=404)

        prompt = build_mannequin_prompt(selected_items, weather, user.gender)

        image_response = client.images.generate(
            model="gpt-image-1",
            prompt=prompt,
            size="1024x1536",
            quality="high",
            n=1,
        )
        if not image_response.data:
            raise TaskError("AI не вернул изображение", status_code=502)

        location_segment = str(location_id) if location_id is not None else "shared"
        image_url = save_mannequin_image(
            image_response.data[0].b64_json, user_id, location_segment
        )

        mannequin_items = [
            schemas.MannequinItem.model_validate(item, from_attributes=True)
            for item in selected_items
        ]
        serialized_items = [item.model_dump() for item in mannequin_items]
        weather_payload = {
            "temperature": coerce_int(weather.temperature),
            "humidity": coerce_int(weather.humidity),
            "condition": weather.condition,
            "wind_speed": coerce_int(weather.wind_speed),
        }

        with db_session() as session:
            mannequin_record = models.MannequinImage(
                user_id=user_id,
                location_id=location_id,
                image_url=image_url,
                items=serialized_items,
                weather=weather_payload,
            )
            session.add(mannequin_record)
            session.commit()

        return {
            "image_url": image_url,
            "weather": weather_payload,
            "items": serialized_items,
        }

    return _run_with_metrics("ai.generate_mannequin", _impl)


@celery_app.task(
    bind=True,
    name="ai.analyze_clothes_image",
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_jitter=True,
    retry_kwargs={"max_retries": 3},
)
def analyze_clothes_image_task(
    self,
    payload: Dict[str, Any],
    mode: str = "validated",
) -> Dict[str, Any]:
    client = get_openai_client()

    def _build_messages(image_payload: str, is_b64: bool) -> List[Dict[str, Any]]:
        img_part = (
            {"type": "image_url", "image_url": {"url": image_payload}}
            if not is_b64
            else {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_payload}"}}
        )
        return [
            {
                "role": "system",
                "content": (
                    "You are a fashion product analyst. Identify garment details strictly from the image. "
                    "Return ONLY valid JSON that matches the provided JSON Schema. "
                    "All textual values (titles, descriptions, prompts, hints, tags, etc.) must be written in Russian."
                ),
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": (
                            "Проанализируй одежду и верни JSON по схеме. "
                            "Все текстовые поля (включая title, catalog_description, gen_prompt, pairing_hints, tags) "
                            "должны быть на русском языке. "
                            "Сформируй лаконичный 'catalog_description' и нейтральный 'gen_prompt' для манекена "
                            "(студийный свет, белый фон, без логотипов/текста). Добавь 3–5 'pairing_hints'."
                        ),
                    },
                    img_part,
                ],
            },
        ]

    def _impl() -> Dict[str, Any]:
        image_payload = payload.get("data")
        if not image_payload:
            raise TaskError("Пустое изображение", status_code=400)
        is_b64 = bool(payload.get("is_b64", False))

        messages = _build_messages(image_payload, is_b64)
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            response_format={
                "type": "json_schema",
                "json_schema": {
                    "name": "ClothesInsights",
                    "schema": JSON_SCHEMA,
                    "strict": True,
                },
            },
            temperature=0.2,
        )
        msg = response.choices[0].message if response.choices else None
        content = msg.content if msg else None
        if not content:
            raise TaskError("AI вернул пустой ответ", status_code=502)

        if mode == "validated":
            try:
                validated = schemas.ClothesInsights.model_validate_json(content)
            except Exception as exc:
                raise TaskError(f"Response schema validation failed: {exc}", status_code=422) from exc
            return {"insights": validated.model_dump()}

        if mode == "raw":
            try:
                return {"raw": json.loads(content)}
            except json.JSONDecodeError:
                return {"raw_text": content}

        raise TaskError("Неподдерживаемый режим обработки", status_code=400)

    task_label = (
        "ai.analyze_clothes_image.validated"
        if mode == "validated"
        else "ai.analyze_clothes_image.raw"
    )
    return _run_with_metrics(task_label, _impl)


__all__ = [
    "analyze_clothes_image_task",
    "generate_mannequin_task",
    "generate_recommendation_task",
]
