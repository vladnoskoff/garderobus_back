"""Shared helper utilities for AI-powered wardrobe features."""

from __future__ import annotations

import base64
import json
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from uuid import uuid4
from typing import Iterable, List, Optional, Tuple, Union

import settings

MANNEQUIN_DIR = settings.MANNEQUIN_IMAGE_DIR
MANNEQUIN_DIR.mkdir(parents=True, exist_ok=True)


def coerce_int(value: Optional[Union[int, float, Decimal]]) -> Optional[int]:
    """Convert numeric values that may be decimals to ints."""

    if value is None:
        return None
    if isinstance(value, Decimal):
        return int(round(float(value)))
    if isinstance(value, float):
        return int(round(value))
    return int(value)


def _safe_metadata(item) -> dict:
    payload = getattr(item, "ai_metadata", None)
    if not payload:
        return {}
    if isinstance(payload, dict):
        return payload
    try:
        return json.loads(payload)
    except (TypeError, json.JSONDecodeError):
        return {}


def extract_temp_range(item) -> Tuple[Optional[int], Optional[int]]:
    meta = _safe_metadata(item)
    min_temp: Optional[int] = None
    max_temp: Optional[int] = None

    range_from_meta = meta.get("temp_c_range") if isinstance(meta, dict) else None
    if range_from_meta and isinstance(range_from_meta, (list, tuple)):
        cleaned: list[int] = []
        for value in range_from_meta:
            try:
                cleaned.append(int(value))
            except (TypeError, ValueError):
                continue

        if cleaned:
            cleaned.sort()
            min_temp = cleaned[0]
            max_temp = cleaned[-1]

    return min_temp, max_temp


def _temperature_score(temperature: float, temp_range: Tuple[Optional[int], Optional[int]]) -> float:
    min_temp, max_temp = temp_range
    if min_temp is None and max_temp is None:
        return abs(temperature)
    if min_temp is None:
        return max(0, temperature - max_temp)  # type: ignore[arg-type]
    if max_temp is None:
        return max(0, min_temp - temperature)  # type: ignore[arg-type]
    if min_temp <= temperature <= max_temp:
        return 0
    if temperature < min_temp:
        return min_temp - temperature
    return temperature - max_temp  # type: ignore[return-value]


def filter_by_season(clothes: Iterable, weather) -> List:
    season_markers = {
        "зима": range(-50, 1),
        "весна": range(1, 16),
        "осень": range(5, 16),
        "лето": range(16, 60),
    }
    normalized_weather_temp = weather.temperature
    preferred_labels: List[str] = []
    for label, temp_range in season_markers.items():
        if normalized_weather_temp in temp_range:
            preferred_labels.append(label)

    if not preferred_labels:
        preferred_labels = ["универс", "демисезон"]

    def matches(item) -> bool:
        value = (getattr(item, "season", "") or "").lower()
        return any(marker in value for marker in preferred_labels)

    return [item for item in clothes if matches(item)]


def select_outfit(clothes: List, weather) -> List:
    if not clothes:
        return []

    scored_items: List[tuple] = []
    for item in clothes:
        temp_range = extract_temp_range(item)
        score = _temperature_score(weather.temperature, temp_range)
        scored_items.append((item, score))

    scored_items.sort(key=lambda pair: (pair[1], (getattr(pair[0], "category", "") or "").lower()))
    selected: List = []
    used_categories: set[str] = set()

    for item, _ in scored_items:
        category = (getattr(item, "category", "") or "").lower()
        if category and category in used_categories:
            continue
        selected.append(item)
        if category:
            used_categories.add(category)
        if len(selected) >= 4:
            break

    if len(selected) < 3:
        seasonal_candidates = filter_by_season(clothes, weather)
        for item in seasonal_candidates:
            if item not in selected:
                selected.append(item)
            if len(selected) >= 3:
                break

    return selected[:4]


def mannequin_gender_instruction(gender: Optional[str]) -> str:
    if not gender:
        return "Render a gender-neutral mannequin with average adult proportions."

    normalized = gender.strip().lower()
    if any(token in normalized for token in ("female", "woman", "жен")):
        return "Render a full-body female mannequin with realistic proportions for the listed garments."
    if any(token in normalized for token in ("male", "man", "муж")):
        return "Render a full-body male mannequin with realistic proportions for the listed garments."
    return f"Render a full-body mannequin that reflects the user's gender: {gender}."


def build_mannequin_prompt(items: List, weather, gender: Optional[str]) -> str:
    lines = [
        "Create a hyperrealistic studio photograph of a faceless mannequin wearing a cohesive outfit.",
        "Frame the mannequin in a vertical 3:4 composition with generous head and foot margins so the full body is visible.",
        "Show the entire mannequin from head to toe in a neutral pose without any cropping.",
        "Use soft neutral lighting, clean white background, no logos or text.",
        f"Weather context: {weather.condition}, {weather.temperature}°C, humidity {weather.humidity}%, wind {getattr(weather, 'wind_speed', 0) or 0} m/s.",
        "Ensure the outfit feels comfortable for the current weather and coordinates colours harmoniously.",
        mannequin_gender_instruction(gender),
        "Only use the clothing items listed below. Do not add extra garments, accessories or props.",
        "Preserve each garment exactly as described: if the item has no logo, text or print, keep its surfaces plain.",
        "Never invent new graphics, move logos between garments, or add embellishments that are not explicitly listed for the item.",
        "If multiple items are listed, do not blend their branding or designs — keep every piece faithful to its own description only.",
        "Clothing items to include:",
    ]

    for item in items:
        base_description = getattr(item, "prompt_description", None) or f"{getattr(item, 'color', '')} {getattr(item, 'category', '')}"
        temp_min, temp_max = extract_temp_range(item)
        climate_note = ""
        if temp_min is not None or temp_max is not None:
            if temp_min is not None and temp_max is not None:
                climate_note = f" (комфорт от {temp_min}°C до {temp_max}°C)"
            elif temp_min is not None:
                climate_note = f" (подходит при температуре от {temp_min}°C)"
            elif temp_max is not None:
                climate_note = f" (подходит до {temp_max}°C)"
        lines.append(
            f"- {base_description.strip()} (season: {getattr(item, 'season', None)}){climate_note}"
        )

    return "\n".join(lines)


def save_mannequin_image(image_b64: str, user_id: int, location_segment: str) -> str:
    """Persist a mannequin image to disk and return the public URL."""

    filename = f"mannequin_{datetime.now().strftime('%Y%m%d%H%M%S')}_{uuid4().hex}.png"
    target_dir: Path = MANNEQUIN_DIR / str(user_id) / location_segment
    target_dir.mkdir(parents=True, exist_ok=True)

    file_path = target_dir / filename
    image_bytes = base64.b64decode(image_b64)
    with open(file_path, "wb") as output:
        output.write(image_bytes)

    relative_path = f"{user_id}/{location_segment}/{filename}"
    url_prefix = settings.MANNEQUIN_IMAGE_URL_PREFIX.rstrip("/") if settings.MANNEQUIN_IMAGE_URL_PREFIX else None
    if url_prefix:
        return f"{url_prefix}/{relative_path}"

    return f"/mannequins/{relative_path}"


__all__ = [
    "build_mannequin_prompt",
    "coerce_int",
    "extract_temp_range",
    "filter_by_season",
    "mannequin_gender_instruction",
    "save_mannequin_image",
    "select_outfit",
]
