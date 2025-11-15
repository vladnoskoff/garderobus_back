"""Wardrobe service routers mirroring the monolith API surface."""

from fastapi import APIRouter

from . import clothes, esp_display, locations, outfits, wardrobe_analytics

router = APIRouter()
router.include_router(clothes.router)
router.include_router(locations.router)
router.include_router(outfits.router)
router.include_router(wardrobe_analytics.router)
router.include_router(esp_display.router)

__all__ = ["router"]
