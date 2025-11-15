"""DDL helpers for the weather service schema."""

from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.engine import Engine


def ensure_schema(engine: Engine) -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR NOT NULL,
                    email VARCHAR(255) UNIQUE NOT NULL,
                    phone VARCHAR(32),
                    password_hash VARCHAR(255) NOT NULL,
                    pin_hash VARCHAR(255),
                    openai_api_key VARCHAR,
                    weather_api_key VARCHAR,
                    location VARCHAR,
                    gender VARCHAR,
                    theme_preference VARCHAR NOT NULL DEFAULT 'light',
                    language_preference VARCHAR(10) NOT NULL DEFAULT 'ru',
                    style_preference VARCHAR,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                )
                """
            )
        )
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS wardrobe_locations (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    name VARCHAR NOT NULL,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    latitude DOUBLE PRECISION,
                    longitude DOUBLE PRECISION
                )
                """
            )
        )
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS weather (
                    id SERIAL PRIMARY KEY,
                    temperature INTEGER NOT NULL,
                    humidity INTEGER NOT NULL,
                    condition VARCHAR NOT NULL,
                    wind_speed NUMERIC,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                )
                """
            )
        )

        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email_weather ON users(email)"
            )
        )
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_weather_created_at ON weather(created_at)"
            )
        )
