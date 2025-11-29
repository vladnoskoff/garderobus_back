"""Profiling utilities for capturing hot endpoint performance."""
from __future__ import annotations

import logging
import time
from datetime import datetime
from pathlib import Path
from typing import Iterable

from fastapi import FastAPI
from prometheus_client import Histogram

from api import settings

try:  # pragma: no cover - optional dependency
    from pyinstrument import Profiler
except Exception:  # pragma: no cover - optional dependency
    Profiler = None  # type: ignore

logger = logging.getLogger(__name__)

_hot_endpoint_latency = Histogram(
    "app_hot_endpoint_latency_seconds",
    "Latency distribution for configured hot endpoints.",
    labelnames=("path",),
)


def _should_profile(path: str, prefixes: Iterable[str]) -> bool:
    return any(path.startswith(prefix) for prefix in prefixes)


class HotPathProfilerMiddleware:
    def __init__(self, app: FastAPI, *, prefixes: Iterable[str]) -> None:
        self.app = app
        self.prefixes = tuple(prefixes)
        self.output_dir: Path = settings.PROFILING_OUTPUT_DIR
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.enabled = settings.PROFILING_ENABLED and Profiler is not None

    async def __call__(self, scope, receive, send):  # type: ignore[override]
        if scope.get("type") != "http" or not self.enabled:
            return await self.app(scope, receive, send)

        path = scope.get("path") or ""
        if not _should_profile(path, self.prefixes):
            return await self.app(scope, receive, send)

        profiler = Profiler(interval=settings.PROFILING_SAMPLING_INTERVAL, async_mode="enabled")
        profiler.start()
        start = time.perf_counter()
        try:
            return await self.app(scope, receive, send)
        finally:
            duration = time.perf_counter() - start
            _hot_endpoint_latency.labels(path=path).observe(duration)
            profiler.stop()
            if settings.PROFILING_WRITE_FLAMEGRAPH:
                timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S")
                safe_path = path.strip("/") or "root"
                safe_path = safe_path.replace("/", "_")
                target = self.output_dir / f"{safe_path}-{timestamp}.html"
                try:
                    target.write_text(profiler.output_html(), encoding="utf-8")
                    logger.info(
                        "Captured flamegraph for %s", path, extra={"file": str(target)}
                    )
                except Exception as exc:  # pragma: no cover - defensive logging
                    logger.warning("Failed to persist profile for %s: %s", path, exc)


def setup_profiling(app: FastAPI) -> None:
    """Attach profiling middleware when enabled and dependencies are available."""

    if not settings.PROFILING_ENABLED:
        logger.info("Hot-path profiling disabled via configuration")
        return

    if Profiler is None:
        logger.warning("pyinstrument is not installed; profiling middleware not added")
        return

    prefixes = settings.PROFILING_ENDPOINT_PREFIXES
    if not prefixes:
        logger.info("No profiling endpoints configured; skipping middleware")
        return

    app.add_middleware(HotPathProfilerMiddleware, prefixes=prefixes)
    logger.info(
        "Hot-path profiling enabled", extra={"paths": prefixes, "output": str(settings.PROFILING_OUTPUT_DIR)}
    )


__all__ = ["setup_profiling", "HotPathProfilerMiddleware"]
