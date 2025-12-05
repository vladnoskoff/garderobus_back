"""Celery application configuration for the Smart Closet backend."""

from __future__ import annotations

from celery import Celery, signals

import settings
import task_tracking


celery_app = Celery(
    "garderobus",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["tasks.ai"],
)

celery_app.conf.update(
    task_default_queue=settings.CELERY_DEFAULT_QUEUE,
    task_acks_late=True,
    worker_prefetch_multiplier=settings.CELERY_WORKER_PREFETCH_MULTIPLIER,
    result_expires=settings.CELERY_RESULT_EXPIRES,
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_soft_time_limit=settings.CELERY_TASK_SOFT_TIME_LIMIT,
    task_time_limit=settings.CELERY_TASK_HARD_TIME_LIMIT,
)


@signals.after_task_publish.connect
def _track_publish(sender=None, headers=None, body=None, **kwargs):
    task_id = None
    task_name = None
    if headers and isinstance(headers, dict):
        task_id = headers.get("id")
        task_name = headers.get("task")
    if not task_id and kwargs.get("headers"):
        task_id = kwargs["headers"].get("id")
    if task_name is None and sender is not None:
        task_name = getattr(sender, "name", str(sender))

    task_tracking.upsert_task_run(
        task_id=str(task_id or ""),
        name=str(task_name or ""),
        status="pending",
        progress=0,
    )


@signals.task_prerun.connect
def _track_start(task_id=None, task=None, *args, **kwargs):
    name = getattr(task, "name", str(task)) if task is not None else ""
    task_tracking.upsert_task_run(
        task_id=str(task_id or ""),
        name=name,
        status="running",
        progress=0,
    )


@signals.task_success.connect
def _track_success(sender=None, result=None, **kwargs):
    task_id = kwargs.get("task_id")
    name = getattr(sender, "name", str(sender)) if sender is not None else ""
    task_tracking.upsert_task_run(
        task_id=str(task_id or ""),
        name=name,
        status="success",
        progress=100,
    )


@signals.task_failure.connect
def _track_failure(sender=None, task_id=None, exception=None, einfo=None, **kwargs):
    name = getattr(sender, "name", str(sender)) if sender is not None else ""
    log_excerpt = None
    if einfo is not None:
        log_excerpt = str(einfo)
    elif exception is not None:
        log_excerpt = str(exception)

    task_tracking.upsert_task_run(
        task_id=str(task_id or ""),
        name=name,
        status="failure",
        error_message=str(exception) if exception else None,
        log_excerpt=log_excerpt,
    )


__all__ = ["celery_app"]
