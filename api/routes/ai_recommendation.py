from __future__ import annotations

from typing import Any, Callable, Dict, Optional

import asyncio
from concurrent.futures import ThreadPoolExecutor

import logging
from uuid import uuid4

from celery import states
from celery.result import AsyncResult, EagerResult
from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

import models
import schemas
from celery_app import celery_app
from database import get_db
from tasks.ai import generate_mannequin_task, generate_recommendation_task
from .location_utils import ensure_location_for_user

from celery.exceptions import CeleryError
from kombu.exceptions import OperationalError as KombuOperationalError


logger = logging.getLogger(__name__)


router = APIRouter(prefix="/ai", tags=["AI Recommendations"])

INLINE_TASK_RESULTS: Dict[str, schemas.TaskStatusResponse] = {}
INLINE_EXECUTOR = ThreadPoolExecutor(max_workers=4)


def _submission_response(task_id: str, request: Request) -> schemas.TaskSubmissionResponse:
    return schemas.TaskSubmissionResponse(
        task_id=task_id,
        status_url=str(request.url_for("get_ai_task_status", task_id=task_id)),
    )


def _build_task_status_response(
    task_id: str, result: AsyncResult | EagerResult
) -> schemas.TaskStatusResponse:
    state = result.state or states.PENDING
    status = state.lower()
    raw_retries = getattr(result, "retries", 0)
    retries = int(raw_retries or 0)

    response = schemas.TaskStatusResponse(
        task_id=task_id,
        status=status,
        retries=retries,
    )

    if state == states.SUCCESS:
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
    elif state == states.FAILURE:
        response.status = "failure"
        response.error = schemas.TaskErrorPayload(
            status_code=500,
            detail=str(result.info),
        )

    return response


@router.get(
    "/recommendation/{user_id}",
    response_model=schemas.TaskSubmissionResponse,
    summary="Запуск генерации AI-рекомендаций",
)
async def enqueue_recommendation(user_id: int, request: Request) -> schemas.TaskSubmissionResponse:
    return await _enqueue_task(
        generate_recommendation_task,
        request=request,
        task_kwargs={"user_id": user_id},
    )


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
    return await _enqueue_task(
        generate_mannequin_task,
        request=request,
        task_kwargs={"user_id": user_id, "location_id": location_id},
    )


async def _run_inline_task(
    task: Callable[..., AsyncResult],
    task_id: str,
    task_kwargs: dict[str, Any],
) -> None:
    loop = asyncio.get_running_loop()

    def _invoke_task() -> AsyncResult | EagerResult:
        return task.apply(args=[], kwargs=task_kwargs, throw=False)

    try:
        inline_result = await loop.run_in_executor(INLINE_EXECUTOR, _invoke_task)
    except Exception as exc:  # pragma: no cover - defensive, should not happen with throw=False
        logger.exception("Inline task %s crashed", task_id)
        INLINE_TASK_RESULTS[task_id] = schemas.TaskStatusResponse(
            task_id=task_id,
            status="failure",
            retries=0,
            error=schemas.TaskErrorPayload(status_code=500, detail=str(exc)),
        )
    else:
        status_response = _build_task_status_response(task_id, inline_result)
        INLINE_TASK_RESULTS[task_id] = status_response


async def _enqueue_task(
    task: Callable[..., AsyncResult],
    *,
    request: Request,
    task_kwargs: dict[str, Any],
) -> schemas.TaskSubmissionResponse:
    try:
        async_result = task.delay(**task_kwargs)
    except (KombuOperationalError, CeleryError):
        task_name = getattr(task, "name", repr(task))
        logger.warning(
            "Failed to enqueue Celery task %s; executing inline due to queue error",
            task_name,
            exc_info=True,
        )
        task_id = f"inline-{uuid4()}"
        INLINE_TASK_RESULTS[task_id] = schemas.TaskStatusResponse(
            task_id=task_id,
            status="pending",
            retries=0,
        )
        asyncio.create_task(_run_inline_task(task, task_id, task_kwargs))
        return _submission_response(task_id, request)

    return _submission_response(async_result.id, request)


@router.get(
    "/tasks/{task_id}",
    response_model=schemas.TaskStatusResponse,
    summary="Получение статуса асинхронной задачи",
    name="get_ai_task_status",
)
async def get_task_status(task_id: str) -> schemas.TaskStatusResponse:
    inline_response = INLINE_TASK_RESULTS.get(task_id)
    if inline_response is not None:
        return inline_response

    result = AsyncResult(task_id, app=celery_app)
    return _build_task_status_response(task_id, result)


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
