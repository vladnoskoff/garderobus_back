from functools import lru_cache
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = Field(default="Weather Service")
    openweathermap_api_key: str
    http_timeout: float = Field(default=5.0)
    cache_ttl_seconds: int = Field(default=900)


@lru_cache
def get_settings() -> Settings:
    return Settings()
