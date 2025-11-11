from functools import lru_cache
from pydantic import BaseSettings, Field, HttpUrl


class Settings(BaseSettings):
    app_name: str = Field(default="Garderobus API Gateway", env="APP_NAME")
    auth_service_url: HttpUrl = Field(env="AUTH_SERVICE_URL")
    wardrobe_service_url: HttpUrl = Field(env="WARDROBE_SERVICE_URL")
    weather_service_url: HttpUrl = Field(env="WEATHER_SERVICE_URL")
    ai_service_url: HttpUrl = Field(env="AI_SERVICE_URL")

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
