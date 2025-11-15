"""Helpers for working with media storage."""

from pathlib import Path
from typing import BinaryIO
from uuid import uuid4

from .config import get_settings


settings = get_settings()
MEDIA_ROOT = Path("/data/media")


def save_media(file_obj: BinaryIO, filename: str) -> str:
    MEDIA_ROOT.mkdir(parents=True, exist_ok=True)
    unique_name = f"{uuid4().hex}_{filename}"
    destination = MEDIA_ROOT / unique_name
    with destination.open("wb") as output:
        output.write(file_obj.read())
    return f"{settings.minio_endpoint}/{settings.media_bucket}/{unique_name}"
