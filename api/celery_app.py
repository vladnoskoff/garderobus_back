"""Celery application configuration for the Smart Closet backend."""

from __future__ import annotations

import hashlib
import json
import logging
from typing import Any, Dict, Optional

from celery import Celery, Task, states
from kombu import Queue

import observability
import settings

log = logging.getLogger(__name__)


def _idempotency_task_id(task_name: str, idempotency_key: str) -> str:
    """Build a deterministic task_id for idempotent submissions."""

    digest = hashlib.sha256(f"{task_name}:{idempotency_key}".encode())
    return digest.hexdigest()


class IdempotentTask(Task):
    """Base task that supports idempotency, deduplication and DLQ forwarding."""

    abstract = True

    def apply_async(  # type: ignore[override]
        self,
        args: Optional[tuple] = None,
        kwargs: Optional[dict] = None,
        task_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        **options: Any,
    ):
        kwargs = kwargs or {}
        headers: Dict[str, Any] = options.setdefault("headers", {})
        idempotency_header = idempotency_key or kwargs.pop("idempotency_key", None)
        if idempotency_header:
            headers["idempotency_key"] = str(idempotency_header)
            task_id = task_id or _idempotency_task_id(self.name, str(idempotency_header))

        return super().apply_async(
            args=args, kwargs=kwargs, task_id=task_id, **options
        )

    def __call__(self, *args: Any, **kwargs: Any):  # type: ignore[override]
        cached_result = self._cached_result(self.request.id)
        if cached_result is not None:
            log.info(
                "Skip duplicate task execution due to cached result",
                extra={
                    "task": self.name,
                    "task_id": self.request.id,
                    "idempotency_key": self.request.headers.get("idempotency_key"),
                },
            )
            return cached_result
        return super().__call__(*args, **kwargs)

    def _cached_result(self, task_id: str) -> Optional[Any]:
        if not task_id:
            return None
        meta = self.backend.get_task_meta(task_id)
        if meta and meta.get("status") == states.SUCCESS:
            return meta.get("result")
        return None

    def after_return(  # type: ignore[override]
        self,
        status: str,
        retval: Any,
        task_id: str,
        args: tuple,
        kwargs: dict,
        einfo: Any,
    ) -> None:
        retry_count = getattr(self.request, "retries", 0)
        idempotency_key = self.request.headers.get("idempotency_key")

        if status == states.RETRY:
            observability.record_celery_retry(self.name)
            if retry_count >= settings.CELERY_RETRY_ALERT_THRESHOLD:
                log.warning(
                    "Retry threshold reached for task",
                    extra={
                        "task": self.name,
                        "task_id": task_id,
                        "retries": retry_count,
                        "idempotency_key": idempotency_key,
                    },
                )

        if status == states.FAILURE:
            log.error(
                "Task exceeded max retries; forwarding to dead-letter queue",
                extra={
                    "task": self.name,
                    "task_id": task_id,
                    "retries": retry_count,
                    "idempotency_key": idempotency_key,
                },
            )
            observability.record_dead_letter(self.name)
            self._send_dead_letter(task_id, args, kwargs, retval)

        super().after_return(status, retval, task_id, args, kwargs, einfo)

    def _send_dead_letter(
        self, task_id: str, args: tuple, kwargs: dict, retval: Any
    ) -> None:
        payload = {
            "task": self.name,
            "task_id": task_id,
            "args": args,
            "kwargs": kwargs,
            "error": str(retval),
        }
        body = json.dumps(payload)
        try:
            self.app.send_task(
                "tasks.dead_letter.handle_dead_letter",
                args=[body],
                queue=settings.CELERY_DEAD_LETTER_QUEUE,
            )
        except Exception:  # pragma: no cover - transport layer failures
            log.exception("Failed to forward task to dead-letter queue")


celery_app = Celery(
    "garderobus",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["tasks.ai", "tasks.dead_letter"],
    task_cls=IdempotentTask,
)

celery_app.conf.update(
    task_default_queue=settings.CELERY_DEFAULT_QUEUE,
    task_default_exchange=settings.CELERY_DEFAULT_QUEUE,
    task_default_routing_key=settings.CELERY_DEFAULT_QUEUE,
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
    task_always_eager=False,
    task_store_eager_result=True,
    task_default_delivery_mode="persistent",
    task_queues=(
        Queue(settings.CELERY_DEFAULT_QUEUE, routing_key=settings.CELERY_DEFAULT_QUEUE),
        Queue(
            settings.CELERY_DEAD_LETTER_QUEUE,
            routing_key=settings.CELERY_DEAD_LETTER_QUEUE,
            durable=True,
        ),
    ),
)


__all__ = ["celery_app", "IdempotentTask"]
