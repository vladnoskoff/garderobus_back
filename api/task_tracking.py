from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

import logging

from sqlalchemy.exc import SQLAlchemyError

import models
from database import SessionLocal

logger = logging.getLogger(__name__)


_STATUS_ORDER = {
    "pending": 0,
    "running": 1,
    "success": 2,
    "failure": 2,
}


def _coerce_progress(progress: Optional[int]) -> int:
    if progress is None:
        return 0
    try:
        value = int(progress)
    except (TypeError, ValueError):
        return 0
    return max(0, min(100, value))


def _status_precedence(current: str, incoming: str) -> str:
    if incoming not in _STATUS_ORDER:
        return current
    if current not in _STATUS_ORDER:
        return incoming
    return incoming if _STATUS_ORDER[incoming] >= _STATUS_ORDER[current] else current


def upsert_task_run(
    *,
    task_id: str,
    name: str,
    status: str,
    progress: Optional[int] = None,
    error_message: Optional[str] = None,
    log_excerpt: Optional[str] = None,
    meta: Optional[dict[str, Any]] = None,
) -> None:
    """Persist basic task telemetry for admin visibility."""

    if not task_id:
        return

    try:
        with SessionLocal() as session:
            record = session.get(models.TaskRun, task_id)
            now = datetime.utcnow()
            if record is None:
                record = models.TaskRun(
                    id=task_id,
                    name=name,
                    status=status,
                    progress=_coerce_progress(progress),
                    error_message=error_message,
                    log_excerpt=log_excerpt,
                    created_at=now,
                    started_at=now if status == "running" else None,
                    finished_at=now if status in {"success", "failure"} else None,
                    meta=meta,
                )
                session.add(record)
            else:
                record.status = _status_precedence(record.status or "pending", status)
                record.name = record.name or name
                if progress is not None:
                    record.progress = _coerce_progress(progress)
                if error_message:
                    record.error_message = error_message
                if log_excerpt:
                    record.log_excerpt = log_excerpt
                if meta:
                    record.meta = meta
                if status == "running" and record.started_at is None:
                    record.started_at = now
                if status in {"success", "failure"}:
                    record.finished_at = now
                record.updated_at = now

            session.commit()
    except SQLAlchemyError:
        logger.warning("Failed to persist task run telemetry", exc_info=True)


def update_progress(task, progress: int, message: Optional[str] = None) -> None:
    """Update Celery task meta and persist progress in DB."""

    task_id = getattr(getattr(task, "request", None), "id", "") or ""
    task_name = getattr(task, "name", "") or task.__class__.__name__
    clamped_progress = _coerce_progress(progress)
    meta: dict[str, Any] = {"progress": clamped_progress}
    if message:
        meta["message"] = message

    try:
        task.update_state(state="PROGRESS", meta=meta)
    except Exception:
        logger.debug("Unable to update Celery state for %s", task_id, exc_info=True)

    upsert_task_run(
        task_id=task_id,
        name=task_name,
        status="running",
        progress=clamped_progress,
        log_excerpt=message,
        meta=meta,
    )


def get_task_run(task_id: str) -> Optional[models.TaskRun]:
    if not task_id:
        return None
    with SessionLocal() as session:
        return session.get(models.TaskRun, task_id)
