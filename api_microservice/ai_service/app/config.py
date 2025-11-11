from functools import lru_cache
from pydantic import BaseSettings, Field, HttpUrl


class Settings(BaseSettings):
    app_name: str = Field(default="AI Service", env="APP_NAME")
    database_url: str = Field(env="DATABASE_URL")
    celery_broker_url: str = Field(env="CELERY_BROKER_URL")
    celery_result_backend: str = Field(env="CELERY_RESULT_BACKEND")
    wardrobe_service_url: HttpUrl = Field(env="WARDROBE_SERVICE_URL")

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
