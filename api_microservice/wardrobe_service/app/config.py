from functools import lru_cache
from pydantic import BaseSettings, Field, HttpUrl


class Settings(BaseSettings):
    app_name: str = Field(default="Wardrobe Service", env="APP_NAME")
    database_url: str = Field(env="DATABASE_URL")
    media_bucket: str = Field(env="MEDIA_BUCKET")
    minio_endpoint: HttpUrl = Field(env="MINIO_ENDPOINT")
    auth_service_url: HttpUrl = Field(env="AUTH_SERVICE_URL")

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
