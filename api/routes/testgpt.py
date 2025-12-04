import base64
from typing import Optional

import logging
from pathlib import Path
import sys

from fastapi import APIRouter, File, Form, HTTPException, Request
import schemas
import settings
from openai_client import is_proxy_active

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/ai", tags=["AI Test"])


def _prepare_sys_path() -> None:
    """Ensure project and api directories are importable for Celery tasks."""

    api_dir = Path(__file__).resolve().parents[1]
    project_root = api_dir.parent

    for path in (api_dir, project_root):
        path_str = str(path)
        if path_str not in sys.path:
            sys.path.insert(0, path_str)


def _get_analyze_task():
    """Lazy-load the analyze task with fallbacks to direct file import."""

    import importlib
    import importlib.util

    _prepare_sys_path()

    attempts: list[dict[str, str]] = []
    last_exc: ImportError | None = None

    for module_path in ("tasks.ai", "api.tasks.ai"):
        try:
            module = importlib.import_module(module_path)
        except ImportError as exc:
            attempts.append({"module": module_path, "error": str(exc)})
            last_exc = exc
            continue

        task = getattr(module, "analyze_clothes_image_task", None)
        if task:
            return task

        attempts.append({
            "module": module_path,
            "error": "missing analyze_clothes_image_task",
            "file": getattr(module, "__file__", "<unknown>"),
        })

    tasks_file = Path(__file__).resolve().parents[1] / "tasks" / "ai.py"
    if tasks_file.exists():
        spec = importlib.util.spec_from_file_location("garderobus_tasks_ai", tasks_file)
        if spec and spec.loader:
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            task = getattr(module, "analyze_clothes_image_task", None)
            if task:
                return task
            attempts.append({
                "module": str(tasks_file),
                "error": "missing analyze_clothes_image_task",
                "file": str(tasks_file),
            })

    logger.error("Failed to import analyze_clothes_image_task", extra={"attempts": attempts})
    raise HTTPException(
        status_code=500,
        detail="AI анализ недоступен (проверьте PYTHONPATH и установку api)",
    ) from last_exc


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
