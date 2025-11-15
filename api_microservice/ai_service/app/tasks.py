"""Celery tasks for AI workloads."""

from __future__ import annotations

import random
import time
from typing import Any

from celery import shared_task


def _simulate_latency(min_seconds: float = 1.0, max_seconds: float = 3.0) -> None:
    time.sleep(random.uniform(min_seconds, max_seconds))


@shared_task(name="generate_outfit_recommendation")
def generate_outfit_recommendation(user_id: int) -> dict[str, Any]:
    """Stub task that mimics a long-running recommendation job."""

    _simulate_latency()
    return {
        "status": "success",
        "result": {
            "user_id": user_id,
            "recommendations": [
                {"outfit_id": 1, "description": "Casual weekend"},
                {"outfit_id": 2, "description": "Office attire"},
            ],
        },
    }


@shared_task(name="generate_mannequin_image")
def generate_mannequin_image(user_id: int, location_id: int | None = None) -> dict[str, Any]:
    """Stub task that mimics mannequin rendering."""

    _simulate_latency()
    return {
        "status": "success",
        "result": {
            "user_id": user_id,
            "location_id": location_id,
            "image_url": "https://example.com/mannequin.png",
        },
    }
