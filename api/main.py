from fastapi import FastAPI, Response

import models
from database import engine
from routes import (
    users,
    clothes,
    outfits,
    weather,
    ai_recommendation,
    wardrobe_analytics,
    esp_display,
    testgpt,
    locations,
)
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

import settings
from cache import cache
from static_files import CDNStaticFiles

models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# Разрешаем CORS для всех источников
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount(
    "/clothes_images",
    CDNStaticFiles(
        directory=str(settings.CLOTHES_IMAGE_DIR),
        cache_control=settings.STATIC_CACHE_CONTROL,
        cdn_cache_control=settings.CDN_CACHE_CONTROL,
        enable_etag=settings.STATIC_ENABLE_ETAG,
    ),
    name="clothes_images",
)
app.mount(
    "/mannequins",
    CDNStaticFiles(
        directory=str(settings.MANNEQUIN_IMAGE_DIR),
        cache_control=settings.STATIC_CACHE_CONTROL,
        cdn_cache_control=settings.CDN_CACHE_CONTROL,
        enable_etag=settings.STATIC_ENABLE_ETAG,
    ),
    name="mannequins",
)

app.include_router(users.router)
app.include_router(clothes.router)
app.include_router(outfits.router)
app.include_router(weather.router)
app.include_router(ai_recommendation.router)
app.include_router(wardrobe_analytics.router)
app.include_router(esp_display.router)
app.include_router(testgpt.router)
app.include_router(locations.router)

@app.get("/")
def read_root():
    return {"message": "Smart Closet API is running!"}


@app.get("/metrics", tags=["monitoring"], summary="Prometheus metrics endpoint")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/healthz", tags=["health"], summary="Service health probe")
def healthcheck() -> dict[str, str]:
    """Simple endpoint used by load balancers and orchestrators."""

    return {"status": "ok"}


@app.on_event("shutdown")
def shutdown_event() -> None:
    """Dispose of the SQLAlchemy engine so connections close gracefully."""

    engine.dispose()
    cache.close()
