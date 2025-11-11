"""Application entrypoint for the wardrobe service."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .routers import router as wardrobe_router


settings = get_settings()

app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(wardrobe_router)


@app.get("/healthz", tags=["health"])
def healthcheck() -> dict:
    return {"status": "ok", "service": settings.app_name}
