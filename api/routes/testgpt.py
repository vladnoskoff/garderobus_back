import base64
import importlib.util
import logging
from pathlib import Path
import sys
from typing import Optional

from fastapi import APIRouter, File, Form, HTTPException, Request
import schemas
import settings
from openai_client import is_proxy_active

logger = logging.getLogger(__name__)


def _bootstrap_import_paths() -> Path | None:
    """Ensure project/API paths are on sys.path and locate task_importer."""

    here = Path(__file__).resolve()
    candidates: list[Path] = []

    # Look through common roots: current file tree, cwd, and their parents
    candidates.extend([here.parents[1], here.parents[2]])
    cwd = Path.cwd()
    candidates.extend([cwd, cwd.parent])

    for base in candidates:
        api_dir = base if base.name == "api" else base / "api"
        task_path = api_dir / "utils" / "task_importer.py"
        if not task_path.exists():
            continue

        project_root = api_dir.parent
        for path in (api_dir, project_root):
            path_str = str(path)
            if path_str not in sys.path:
                sys.path.insert(0, path_str)

        return task_path

    return None


def _import_task_importer():
    try:  # Prefer package import when project root is on sys.path
        from api.utils.task_importer import load_tasks_module
        return load_tasks_module
    except ImportError:
        pass

    module_path = _bootstrap_import_paths()
    if module_path is not None:
        spec = importlib.util.spec_from_file_location("utils.task_importer", module_path)
        if spec and spec.loader:
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module.load_tasks_module

    raise ImportError("Unable to import load_tasks_module from utils.task_importer")


load_tasks_module = _import_task_importer()


router = APIRouter(prefix="/ai", tags=["AI Test"])


def _get_analyze_task():
    api_dir = Path(__file__).resolve().parents[1]
    tasks_file = api_dir / "tasks" / "ai.py"

    module = load_tasks_module(
        required_attrs=("analyze_clothes_image_task",),
        api_dir=api_dir,
        logger=logger,
        fallback_file=tasks_file,
    )

    return module.analyze_clothes_image_task


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
