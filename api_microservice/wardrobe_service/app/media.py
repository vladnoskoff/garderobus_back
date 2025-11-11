"""Helpers for working with media storage."""

from pathlib import Path
from typing import BinaryIO

from .config import get_settings


settings = get_settings()
MEDIA_ROOT = Path("/data/media")


def save_media(file_obj: BinaryIO, filename: str) -> str:
    MEDIA_ROOT.mkdir(parents=True, exist_ok=True)
    destination = MEDIA_ROOT / filename
    with destination.open("wb") as output:
        output.write(file_obj.read())
    return f"{settings.minio_endpoint}/{settings.media_bucket}/{filename}"
