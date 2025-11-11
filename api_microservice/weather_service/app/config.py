from functools import lru_cache
from pydantic import BaseSettings, Field


class Settings(BaseSettings):
    app_name: str = Field(default="Weather Service", env="APP_NAME")
    openweathermap_api_key: str = Field(env="OPENWEATHERMAP_API_KEY")
    http_timeout: float = Field(default=5.0, env="HTTP_TIMEOUT")
    cache_ttl_seconds: int = Field(default=900, env="CACHE_TTL_SECONDS")

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
