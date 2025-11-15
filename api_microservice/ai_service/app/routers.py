"""Endpoints for scheduling AI jobs and retrieving results."""

from __future__ import annotations

import asyncio
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Dict, Optional
from uuid import uuid4

from celery import states
from celery.result import AsyncResult, EagerResult
from fastapi import APIRouter, HTTPException, Query, Request

from .tasks import generate_mannequin_image, generate_outfit_recommendation
from .worker import app as celery_app


router = APIRouter(prefix="/ai", tags=["ai"])

INLINE_RESULTS: Dict[str, Dict[str, Any]] = {}
EXECUTOR = ThreadPoolExecutor(max_workers=4)


def _enqueue_task(task, *, task_kwargs: dict[str, Any]) -> str:
    try:
        async_result = task.delay(**task_kwargs)
    except Exception:
        task_id = f"inline-{uuid4()}"
        INLINE_RESULTS[task_id] = {"status": states.PENDING.lower()}

        async def _run_inline() -> None:
            loop = asyncio.get_running_loop()

            def _invoke() -> AsyncResult | EagerResult:
                return task.apply(args=[], kwargs=task_kwargs, throw=False)

            result = await loop.run_in_executor(EXECUTOR, _invoke)
            INLINE_RESULTS[task_id] = _serialize_result(task_id, result)

        asyncio.create_task(_run_inline())
        return task_id

    return async_result.id


def _serialize_result(task_id: str, result: AsyncResult | EagerResult) -> Dict[str, Any]:
    state = (result.state or states.PENDING).lower()
    response: Dict[str, Any] = {"task_id": task_id, "status": state, "retries": int(getattr(result, "retries", 0) or 0)}

    if state == states.SUCCESS.lower():
        payload = result.result
        if isinstance(payload, dict) and "status" in payload:
            response.update(payload)
        else:
            response.update({"status": "success", "result": payload})
    elif state == states.FAILURE.lower():
        response.update({"status": "failure", "error": str(result.info)})

    return response


def _build_submission(task_id: str, request: Request) -> Dict[str, Any]:
    return {
        "task_id": task_id,
        "status_url": str(request.url_for("get_ai_task_status", task_id=task_id)),
    }


@router.post("/recommendations", status_code=202)
async def schedule_recommendation(user_id: int, request: Request) -> Dict[str, Any]:
    task_id = _enqueue_task(generate_outfit_recommendation, task_kwargs={"user_id": user_id})
    return _build_submission(task_id, request)


@router.get("/recommendation/{user_id}", status_code=202)
async def enqueue_recommendation(user_id: int, request: Request) -> Dict[str, Any]:
    return await schedule_recommendation(user_id=user_id, request=request)


@router.get("/mannequin/{user_id}", status_code=202)
async def enqueue_mannequin(
    user_id: int,
    request: Request,
    location_id: Optional[int] = Query(default=None, description="Wardrobe location identifier"),
) -> Dict[str, Any]:
    task_id = _enqueue_task(
        generate_mannequin_image,
        task_kwargs={"user_id": user_id, "location_id": location_id},
    )
    return _build_submission(task_id, request)


@router.get("/tasks/{task_id}", name="get_ai_task_status")
async def get_task_status(task_id: str) -> Dict[str, Any]:
    inline = INLINE_RESULTS.get(task_id)
    if inline:
        return inline

    result = AsyncResult(task_id, app=celery_app)
    if result.state is None:
        raise HTTPException(status_code=404, detail="Задача не найдена")
    return _serialize_result(task_id, result)


@router.get("/mannequin/{user_id}/history")
async def get_mannequin_history(user_id: int, limit: int = Query(10, ge=1, le=50)) -> Dict[str, Any]:
    return {
        "user_id": user_id,
        "items": [
            {
                "id": idx,
                "image_url": "https://example.com/mannequin.png",
                "created_at": "2024-01-01T00:00:00Z",
            }
            for idx in range(1, limit + 1)
        ],
    }
