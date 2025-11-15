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
    openai_api_key: str = Field(
        default=(
            "sk-proj-meOKTsNkP_Gp17p9tWbHCNBT8Y2qidUHCQFkrZ6bRB_R0yUB3qi0OIvILCAs-"
            "SobJ5yqq8nr2lT3BlbkFJ4j5ALz62zsZLzf0m2q97QoMbSt_RZWUpBtCG7jh7f4yFfQSpxWgsuX42dizTtDpiiymu0ID0kA"
        )
    )
    openweather_api_key: str = Field(default="b12505dfa3865989452161d336d8ee5c")
    default_user_location: str = Field(default="55.755826, 37.617299")


@lru_cache
def get_settings() -> Settings:
    return Settings()
