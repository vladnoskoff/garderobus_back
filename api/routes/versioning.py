from __future__ import annotations

from fastapi import APIRouter

from . import (
    admin,
    ai_recommendation,
    clothes,
    clothes_update,
    esp_display,
    locations,
    notifications,
    outfits,
    testgpt,
    users,
    wardrobe_analytics,
    weather,
)


def _core_routers() -> list[APIRouter]:
    return [
        admin.router,
        users.router,
        clothes.router,
        clothes_update.router,
        outfits.router,
        weather.router,
        ai_recommendation.router,
        wardrobe_analytics.router,
        esp_display.router,
        testgpt.router,
        locations.router,
        notifications.router,
    ]


def build_versioned_router(prefix: str | None = None, *, deprecated: bool = False) -> APIRouter:
    """Create a composed router with a shared prefix and deprecation flag."""

    router = APIRouter(prefix=prefix or "")
    for child in _core_routers():
        router.include_router(child, deprecated=deprecated)
    return router
