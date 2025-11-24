"""Caching utilities for Redis-backed data caching and instrumentation."""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from typing import Any, Optional

import redis
from prometheus_client import Counter

import settings

logger = logging.getLogger(__name__)

CACHE_BACKEND_LABEL = settings.CACHE_BACKEND or "redis"

_cache_hits = Counter(
    "app_cache_hits_total",
    "Total number of cache hits.",
    labelnames=("backend", "resource"),
)
_cache_misses = Counter(
    "app_cache_misses_total",
    "Total number of cache misses.",
    labelnames=("backend", "resource"),
)


@dataclass
class CacheStatus:
    enabled: bool
    backend: str


class CacheService:
    """Simple Redis-backed cache with JSON serialization."""

    def __init__(self) -> None:
        self._client: Optional[redis.Redis] = None
        self._enabled = settings.CACHE_ENABLED

        if not self._enabled:
            logger.info("Application cache disabled via configuration")
            return

        try:
            self._client = redis.Redis.from_url(
                settings.CACHE_URL,
                decode_responses=True,
                socket_timeout=settings.CACHE_SOCKET_TIMEOUT,
            )
            # validate connection early
            self._client.ping()
            logger.info("Connected to cache backend at %s", settings.CACHE_URL)
        except redis.RedisError as exc:  # pragma: no cover - defensive branch
            logger.warning("Failed to initialize cache backend: %s", exc)
            self._client = None
            self._enabled = False

    @property
    def enabled(self) -> bool:
        return self._enabled and self._client is not None

    def status(self) -> CacheStatus:
        return CacheStatus(enabled=self.enabled, backend=CACHE_BACKEND_LABEL)

    def make_key(self, *parts: Any) -> str:
        stringified = [str(part) for part in parts]
        return ":".join([settings.CACHE_KEY_PREFIX, *stringified])

    def get_json(self, key: str, resource: str) -> Optional[Any]:
        if not self.enabled:
            return None

        assert self._client is not None  # for type-checkers
        try:
            payload = self._client.get(key)
        except redis.RedisError as exc:
            logger.warning("Redis GET failed for key %s: %s", key, exc)
            return None

        if payload is None:
            _cache_misses.labels(CACHE_BACKEND_LABEL, resource).inc()
            return None

        _cache_hits.labels(CACHE_BACKEND_LABEL, resource).inc()
        try:
            return json.loads(payload)
        except json.JSONDecodeError:
            logger.warning("Failed to decode JSON payload for key %s", key)
            return None

    def set_json(self, key: str, value: Any, ttl: int, resource: str) -> None:
        if not self.enabled:
            return

        assert self._client is not None
        try:
            payload = json.dumps(value, separators=(",", ":"))
            self._client.setex(key, ttl, payload)
        except (TypeError, ValueError) as exc:
            logger.warning("Failed to serialize value for cache key %s: %s", key, exc)
        except redis.RedisError as exc:
            logger.warning("Redis SETEX failed for key %s: %s", key, exc)
        else:
            logger.debug("Cached resource %s under key %s for %s seconds", resource, key, ttl)

    def delete(self, key: str) -> None:
        if not self.enabled:
            return

        assert self._client is not None
        try:
            self._client.delete(key)
        except redis.RedisError as exc:
            logger.warning("Redis DELETE failed for key %s: %s", key, exc)

    def increment(self, key: str, ttl: int) -> int:
        if not self.enabled:
            logger.debug("Cache disabled; returning synthetic counter value for %s", key)
            return 1

        assert self._client is not None
        try:
            value = self._client.incr(key)
            self._client.expire(key, ttl)
            return int(value)
        except redis.RedisError as exc:
            logger.warning("Redis INCR/EXPIRE failed for key %s: %s", key, exc)
            return 1

    def delete_prefix(self, prefix: str) -> None:
        if not self.enabled:
            return

        assert self._client is not None
        pattern = f"{prefix}*"
        try:
            pipeline = self._client.pipeline()
            counter = 0
            for key in self._client.scan_iter(match=pattern):
                pipeline.delete(key)
                counter += 1
                if counter % settings.CACHE_INVALIDATION_BATCH_SIZE == 0:
                    pipeline.execute()
            if counter % settings.CACHE_INVALIDATION_BATCH_SIZE:
                pipeline.execute()
            if counter:
                logger.debug("Invalidated %s keys for prefix %s", counter, prefix)
        except redis.RedisError as exc:
            logger.warning("Redis SCAN/DELETE failed for prefix %s: %s", prefix, exc)

    def close(self) -> None:
        if self._client is not None:
            try:
                self._client.close()
            except redis.RedisError as exc:
                logger.warning("Failed to close Redis connection: %s", exc)
            finally:
                self._client = None


cache = CacheService()


def cache_key(*parts: Any) -> str:
    return cache.make_key(*parts)


def invalidate_clothes_for_user(user_id: int) -> None:
    cache.delete_prefix(cache.make_key("clothes", user_id))


def invalidate_outfit_history_for_user(user_id: int) -> None:
    cache.delete_prefix(cache.make_key("outfit_history", user_id))


def invalidate_locations_for_user(user_id: int) -> None:
    cache.delete_prefix(cache.make_key("locations", user_id))


def invalidate_weather_for_user(user_id: int) -> None:
    cache.delete_prefix(cache.make_key("weather", user_id))
