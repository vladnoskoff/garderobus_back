import base64
from typing import Optional

import logging

from fastapi import APIRouter, File, Form, HTTPException, Request
import schemas
import settings
from openai_client import is_proxy_active

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/ai", tags=["AI Test"])


def _get_analyze_task():
    """Lazy-load the analyze task to tolerate missing PYTHONPATH at startup."""

    try:
        from tasks.ai import analyze_clothes_image_task
    except ImportError as exc:  # pragma: no cover - defensive guard
        logger.exception("Failed to import analyze_clothes_image_task")
        raise HTTPException(
            status_code=500,
            detail="AI анализ недоступен (проверьте PYTHONPATH и установку api)",
        ) from exc

    return analyze_clothes_image_task


def _encode_payload(image_url: Optional[str], file: Optional[bytes]) -> dict:
    if image_url:
        return {"data": image_url, "is_b64": False}
    if file and len(file) > 0:
        return {"data": base64.b64encode(file).decode("utf-8"), "is_b64": True}
    raise HTTPException(status_code=400, detail="Provide image_url or file")


@router.get("/ping")
def ping():
    return {
        "status": "ok",
        "proxy": settings.SOCKS_PROXY_URL if is_proxy_active() else None,
        "message": "AI test route is working",
    }


@router.post(
    "/analyze",
    response_model=schemas.TaskSubmissionResponse,
    summary="Анализ изображения одежды через AI (валидируемый ответ)",
)
async def analyze_image(
    request: Request,
    image_url: Optional[str] = Form(
        None,
        example="https://upload.wikimedia.org/wikipedia/commons/6/6e/Golde33443.jpg",
    ),
    file: Optional[bytes] = File(None),
) -> schemas.TaskSubmissionResponse:
    payload = _encode_payload(image_url, file)
    analyze_task = _get_analyze_task()
    task = analyze_task.delay(payload=payload, mode="validated")
    return schemas.TaskSubmissionResponse(
        task_id=task.id,
        status_url=request.url_for("get_ai_task_status", task_id=task.id),
    )


@router.post(
    "/analyze_raw",
    response_model=schemas.TaskSubmissionResponse,
    summary="Анализ изображения одежды через AI (сырой ответ)",
)
async def analyze_image_raw(
    request: Request,
    image_url: Optional[str] = Form(
        None,
        example="https://upload.wikimedia.org/wikipedia/commons/6/6e/Golde33443.jpg",
    ),
    file: Optional[bytes] = File(None),
) -> schemas.TaskSubmissionResponse:
    payload = _encode_payload(image_url, file)
    analyze_task = _get_analyze_task()
    task = analyze_task.delay(payload=payload, mode="raw")
    return schemas.TaskSubmissionResponse(
        task_id=task.id,
        status_url=request.url_for("get_ai_task_status", task_id=task.id),
    )
