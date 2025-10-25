from __future__ import annotations

from typing import Optional

from celery import states
from celery.result import AsyncResult
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

import models
import schemas
from celery_app import celery_app
from database import get_db
from tasks.ai import generate_mannequin_task, generate_recommendation_task
from .location_utils import ensure_location_for_user


router = APIRouter(prefix="/ai", tags=["AI Recommendations"])


def _submission_response(task_id: str, request: Request) -> schemas.TaskSubmissionResponse:
    return schemas.TaskSubmissionResponse(
        task_id=task_id,
        status_url=request.url_for("get_ai_task_status", task_id=task_id),
    )


@router.get(
    "/recommendation/{user_id}",
    response_model=schemas.TaskSubmissionResponse,
    summary="Запуск генерации AI-рекомендаций",
)
async def enqueue_recommendation(user_id: int, request: Request) -> schemas.TaskSubmissionResponse:
    task = generate_recommendation_task.delay(user_id=user_id)
    return _submission_response(task.id, request)


@router.get(
    "/mannequin/{user_id}",
    response_model=schemas.TaskSubmissionResponse,
    summary="Запуск генерации изображения манекена",
)
async def enqueue_mannequin_generation(
    user_id: int,
    request: Request,
    location_id: Optional[int] = Query(
        default=None, description="Выбор гардероба по локации"
    ),
) -> schemas.TaskSubmissionResponse:
    task = generate_mannequin_task.delay(user_id=user_id, location_id=location_id)
    return _submission_response(task.id, request)


@router.get(
    "/tasks/{task_id}",
    response_model=schemas.TaskStatusResponse,
    summary="Получение статуса асинхронной задачи",
    name="get_ai_task_status",
)
async def get_task_status(task_id: str) -> schemas.TaskStatusResponse:
    result = AsyncResult(task_id, app=celery_app)
    status = result.state.lower()
    retries = getattr(result, "retries", 0)

    response = schemas.TaskStatusResponse(
        task_id=task_id,
        status=status,
        retries=retries,
    )

    if result.state == states.SUCCESS:
        payload = result.result
        if isinstance(payload, dict):
            payload_status = payload.get("status")
            if payload_status == "success":
                response.status = "success"
                response.result = payload.get("result")
            elif payload_status == "error":
                response.status = "error"
                response.error = schemas.TaskErrorPayload(
                    status_code=int(payload.get("status_code", 500)),
                    detail=str(payload.get("detail", "")),
                )
            else:
                response.result = payload
        elif payload is not None:
            response.result = {"value": payload}
    elif result.state == states.FAILURE:
        response.status = "failure"
        response.error = schemas.TaskErrorPayload(
            status_code=500,
            detail=str(result.info),
        )

    return response


@router.get(
    "/mannequin/{user_id}/history",
    response_model=list[schemas.StoredMannequinResponse],
    summary="История сгенерированных изображений",
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
