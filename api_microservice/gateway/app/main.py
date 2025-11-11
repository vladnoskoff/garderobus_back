"""API gateway entrypoint."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .orchestrator import (
    get_ai_recommendation,
    get_current_weather,
    get_user_profile,
    get_wardrobe_items,
)


settings = get_settings()

app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/healthz", tags=["health"])
def healthcheck() -> dict:
    return {"status": "ok", "service": settings.app_name}


@app.get("/api/v1/users/{user_id}", tags=["gateway"])
async def proxy_user_profile(user_id: int) -> dict:
    return await get_user_profile(user_id)


@app.get("/api/v1/weather", tags=["gateway"])
async def proxy_weather(lat: float, lon: float) -> dict:
    return await get_current_weather(lat, lon)


@app.get("/api/v1/wardrobe/items", tags=["gateway"])
async def proxy_wardrobe_items() -> dict:
    return await get_wardrobe_items()


@app.get("/api/v1/ai/recommendations/{task_id}", tags=["gateway"])
async def proxy_ai_recommendation(task_id: str) -> dict:
    return await get_ai_recommendation(task_id)
