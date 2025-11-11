"""Endpoints for scheduling AI jobs and retrieving results."""

from fastapi import APIRouter, HTTPException
from celery.result import AsyncResult

from .tasks import generate_outfit_recommendation
from .worker import app as celery_app


router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/recommendations", status_code=202)
def schedule_recommendation(user_id: int) -> dict:
    task = generate_outfit_recommendation.delay(user_id)
    return {"task_id": task.id}


@router.get("/recommendations/{task_id}")
def get_recommendation(task_id: str) -> dict:
    result = AsyncResult(task_id, app=celery_app)
    if result.failed():
        raise HTTPException(status_code=500, detail="Task failed")
    if not result.ready():
        return {"status": result.status}
    return {"status": "SUCCESS", "data": result.result}
