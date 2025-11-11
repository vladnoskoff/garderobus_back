"""Custom automation hooks for the Garderobus platform.

This module is editable from the admin panel. Use it to register
lightweight post-processing hooks without redeploying the API. The
:func:`get_hooks` function should return an iterable of callables that
accept a payload dictionary and return a modified payload.
"""

from __future__ import annotations

from typing import Any, Callable, Dict, Iterable, List

Hook = Callable[[Dict[str, Any]], Dict[str, Any]]


def sanitize_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Example hook that normalises wardrobe payloads.

    The hook removes empty string values and trims whitespace in
    ``name``-like fields.
    """

    normalized = {key: value for key, value in payload.items() if value not in ("", None)}
    if "name" in normalized and isinstance(normalized["name"], str):
        normalized["name"] = normalized["name"].strip()
    return normalized


def get_hooks() -> Iterable[Hook]:
    hooks: List[Hook] = [sanitize_payload]
    return hooks
