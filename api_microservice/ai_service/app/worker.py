"""Celery worker configuration."""

from celery import Celery

from .config import get_settings


settings = get_settings()

app = Celery(
    "ai_service",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
)

app.autodiscover_tasks(["app.tasks"])
