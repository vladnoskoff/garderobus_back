from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"), env_file_encoding="utf-8", extra="ignore"
    )

    app_name: str = Field(default="Weather Service")
    openweathermap_api_key: str
    http_timeout: float = Field(default=5.0)
    cache_ttl_seconds: int = Field(default=900)
    database_url: str


@lru_cache
def get_settings() -> Settings:
    return Settings()
