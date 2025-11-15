"""DDL helpers to ensure the auth database matches the monolith schema."""

from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.engine import Engine


USER_COLUMNS = (
    ("name", "ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR"),
    ("email", "ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255)"),
    ("phone", "ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(32)"),
    ("password_hash", "ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255)"),
    ("pin_hash", "ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255)"),
    ("openai_api_key", "ALTER TABLE users ADD COLUMN IF NOT EXISTS openai_api_key VARCHAR"),
    ("weather_api_key", "ALTER TABLE users ADD COLUMN IF NOT EXISTS weather_api_key VARCHAR"),
    ("location", "ALTER TABLE users ADD COLUMN IF NOT EXISTS location VARCHAR"),
    ("gender", "ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR"),
    (
        "theme_preference",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS theme_preference VARCHAR DEFAULT 'light'",
    ),
    (
        "language_preference",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS language_preference VARCHAR(10) DEFAULT 'ru'",
    ),
    ("style_preference", "ALTER TABLE users ADD COLUMN IF NOT EXISTS style_preference VARCHAR"),
    (
        "created_at",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()",
    ),
)


def ensure_schema(engine: Engine) -> None:
    """Create tables and columns expected by the monolith."""

    with engine.begin() as connection:
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR,
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

        for _, statement in USER_COLUMNS:
            connection.execute(text(statement))

        # ensure constraints and sensible defaults
        connection.execute(
            text(
                """
                UPDATE users
                SET name = COALESCE(name, email, 'User')
                """
            )
        )
        connection.execute(
            text("ALTER TABLE users ALTER COLUMN name SET NOT NULL")
        )
        connection.execute(
            text("ALTER TABLE users ALTER COLUMN theme_preference SET DEFAULT 'light'")
        )
        connection.execute(
            text("ALTER TABLE users ALTER COLUMN language_preference SET DEFAULT 'ru'")
        )
        connection.execute(
            text("ALTER TABLE users ALTER COLUMN theme_preference SET NOT NULL")
        )
        connection.execute(
            text("ALTER TABLE users ALTER COLUMN language_preference SET NOT NULL")
        )

        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users(email)"
            )
        )
        connection.execute(
            text("CREATE INDEX IF NOT EXISTS ix_users_phone ON users(phone)")
        )
