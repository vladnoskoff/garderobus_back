from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"), env_file_encoding="utf-8", extra="ignore"
    )

    app_name: str = Field(default="Auth Service")
    database_url: str
    jwt_secret: str
    jwt_algorithm: str = Field(default="HS256")
    access_token_expire_minutes: int = Field(default=60)


@lru_cache
def get_settings() -> Settings:
    return Settings()
