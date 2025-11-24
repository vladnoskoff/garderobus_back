"""Dead-letter handler that preserves failed Celery payloads."""

from __future__ import annotations

import json
import logging
from typing import Any, Dict

from celery_app import IdempotentTask, celery_app

log = logging.getLogger(__name__)


@celery_app.task(
    bind=True,
    base=IdempotentTask,
    name="tasks.dead_letter.handle_dead_letter",
    max_retries=0,
)
def handle_dead_letter(self, raw_payload: str) -> Dict[str, Any]:
    try:
        payload = json.loads(raw_payload)
    except json.JSONDecodeError:
        payload = {"raw": raw_payload}

    log.error("Dead-lettered task payload captured", extra=payload)
    return payload


__all__ = ["handle_dead_letter"]
