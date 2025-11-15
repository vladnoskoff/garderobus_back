from functools import lru_cache
from pydantic import Field, HttpUrl
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = Field(default="AI Service")
    database_url: str
    celery_broker_url: str
    celery_result_backend: str
    wardrobe_service_url: HttpUrl


@lru_cache
def get_settings() -> Settings:
    return Settings()
