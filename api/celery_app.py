"""Celery application configuration for the Smart Closet backend."""

from __future__ import annotations

from celery import Celery

import settings


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


__all__ = ["celery_app"]
