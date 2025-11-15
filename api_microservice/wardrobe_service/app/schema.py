"""DDL helpers ensuring the wardrobe schema mirrors the monolith."""

from __future__ import annotations

from sqlalchemy import text
from sqlalchemy.engine import Engine


def ensure_schema(engine: Engine) -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS clothes (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    name VARCHAR NOT NULL,
                    category VARCHAR NOT NULL,
                    season VARCHAR NOT NULL,
                    color VARCHAR NOT NULL,
                    image_url VARCHAR,
                    material VARCHAR,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    prompt_description TEXT,
                    care_instructions TEXT,
                    location_id INTEGER
                )
                """
            )
        )
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS clothes_gallery_images (
                    id SERIAL PRIMARY KEY,
                    clothes_id INTEGER NOT NULL REFERENCES clothes(id) ON DELETE CASCADE,
                    image_url TEXT NOT NULL,
                    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
        )
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS clothes_metadata (
                    clothes_id INTEGER PRIMARY KEY REFERENCES clothes(id) ON DELETE CASCADE,
                    data JSON
                )
                """
            )
        )
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS mannequin_images (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    location_id INTEGER,
                    image_url TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    items JSON,
                    weather JSON
                )
                """
            )
        )
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS outfits (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER,
                    weather_id INTEGER,
                    clothing_ids JSON NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    rating INTEGER,
                    image_url VARCHAR
                )
                """
            )
        )
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS wear_history (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER,
                    clothing_id INTEGER,
                    worn_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
        )
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS wardrobe_locations (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
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
                "CREATE INDEX IF NOT EXISTS ix_clothes_user ON clothes(user_id)"
            )
        )
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_clothes_location ON clothes(location_id)"
            )
        )
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_mannequin_images_user ON mannequin_images(user_id)"
            )
        )
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_outfits_user ON outfits(user_id)"
            )
        )
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_wear_history_user ON wear_history(user_id)"
            )
        )
        connection.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_wardrobe_locations_user ON wardrobe_locations(user_id)"
            )
        )
