from functools import lru_cache
from pathlib import Path

from pydantic import Field, HttpUrl
from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"), env_file_encoding="utf-8", extra="ignore"
    )

    app_name: str = Field(default="Wardrobe Service")
    database_url: str
    media_bucket: str
    minio_endpoint: HttpUrl
    auth_service_url: HttpUrl


@lru_cache
def get_settings() -> Settings:
    return Settings()
