"""Celery tasks for AI workloads."""

from time import sleep
from celery import shared_task


@shared_task(name="generate_outfit_recommendation")
def generate_outfit_recommendation(user_id: int) -> dict:
    """Stub task that mimics a long-running recommendation job."""

    # Placeholder for actual ML inference logic
    sleep(2)
    return {
        "user_id": user_id,
        "recommendations": [
            {"outfit_id": 1, "description": "Casual weekend"},
            {"outfit_id": 2, "description": "Office attire"},
        ],
    }
