"""Caching utilities for Redis-backed data caching and instrumentation."""
from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from time import monotonic
from typing import Any, Dict, Optional, Tuple

import redis
from prometheus_client import Counter, Gauge

import settings

logger = logging.getLogger(__name__)

CACHE_BACKEND_LABEL = settings.CACHE_BACKEND or "redis"
MEMORY_BACKEND_LABEL = "memory"

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

_cache_pool_in_use = Gauge(
    "app_cache_pool_in_use",
    "Number of active connections to the cache backend.",
    labelnames=("backend",),
)
_cache_pool_available = Gauge(
    "app_cache_pool_available",
    "Number of idle connections to the cache backend.",
    labelnames=("backend",),
)
_cache_pool_max = Gauge(
    "app_cache_pool_max",
    "Maximum configured connections for the cache backend.",
    labelnames=("backend",),
)

_cache_memory_hits = Counter(
    "app_cache_memory_hits_total",
    "Cache hits served from the in-process memory layer.",
    labelnames=("resource",),
)
_cache_memory_evictions = Counter(
    "app_cache_memory_evictions_total",
    "Items evicted from the in-process memory cache.",
    labelnames=("resource",),
)


@dataclass
class CacheStatus:
    enabled: bool
    backend: str


class CacheService:
    """Simple Redis-backed cache with JSON serialization and local fallback."""

    def __init__(self, *, force_local_only: bool = False) -> None:
        self._client: Optional[redis.Redis] = None
        self._enabled = settings.CACHE_ENABLED
        self._use_local_cache = settings.CACHE_USE_LOCAL_FALLBACK or force_local_only
        self._local_ttl = settings.CACHE_LOCAL_TTL
        self._local_cache: Dict[str, Tuple[float, Any, str]] = {}

        if not self._enabled:
            logger.info("Application cache disabled via configuration")
            return

        if force_local_only:
            logger.info("Cache running in local-only mode for testing")
            return

        try:
            pool = redis.ConnectionPool.from_url(
                settings.CACHE_URL,
                decode_responses=True,
                socket_timeout=settings.CACHE_SOCKET_TIMEOUT,
                max_connections=settings.CACHE_MAX_CONNECTIONS,
            )
            self._client = redis.Redis(connection_pool=pool)
            # validate connection early
            self._client.ping()
            self._update_pool_metrics()
            logger.info("Connected to cache backend at %s", settings.CACHE_URL)
        except redis.RedisError as exc:  # pragma: no cover - defensive branch
            logger.warning("Failed to initialize cache backend: %s", exc)
            self._client = None

    @property
    def enabled(self) -> bool:
        return self._enabled and (
            self._client is not None or self._use_local_cache
        )

    def status(self) -> CacheStatus:
        return CacheStatus(enabled=self.enabled, backend=CACHE_BACKEND_LABEL)

    def _update_pool_metrics(self) -> None:
        if self._client is None:
            return

        try:
            pool = self._client.connection_pool
            max_connections = getattr(pool, "max_connections", 0) or 0
            in_use = len(getattr(pool, "_in_use_connections", []))
            available = len(getattr(pool, "_available_connections", []))
            _cache_pool_in_use.labels(CACHE_BACKEND_LABEL).set(in_use)
            _cache_pool_available.labels(CACHE_BACKEND_LABEL).set(available)
            _cache_pool_max.labels(CACHE_BACKEND_LABEL).set(max_connections)
        except Exception as exc:  # pragma: no cover - defensive metrics guard
            logger.debug("Unable to export cache pool metrics: %s", exc)

    def _prune_local(self) -> None:
        if not self._use_local_cache or not self._local_cache:
            return

        now = monotonic()
        for key, (expires_at, _, resource) in list(self._local_cache.items()):
            if expires_at <= now:
                self._local_cache.pop(key, None)
                _cache_memory_evictions.labels(resource).inc()

    def _get_local(self, key: str, resource: str) -> Tuple[bool, Optional[Any]]:
        if not self._use_local_cache:
            return False, None

        self._prune_local()
        entry = self._local_cache.get(key)
        if entry is None:
            return False, None

        expires_at, value, _ = entry
        if expires_at <= monotonic():
            self._local_cache.pop(key, None)
            _cache_memory_evictions.labels(resource).inc()
            return False, None

        _cache_memory_hits.labels(resource).inc()
        return True, value

    def _set_local(self, key: str, value: Any, ttl: int, resource: str) -> None:
        if not self._use_local_cache:
            return

        duration = max(ttl or self._local_ttl, 1)
        expires_at = monotonic() + duration
        self._local_cache[key] = (expires_at, value, resource)

    def _delete_local_prefix(self, prefix: str) -> None:
        if not self._use_local_cache:
            return

        for key, (_, _, resource) in list(self._local_cache.items()):
            if key.startswith(prefix):
                self._local_cache.pop(key, None)
                _cache_memory_evictions.labels(resource).inc()

    def make_key(self, *parts: Any) -> str:
        stringified = [str(part) for part in parts]
        return ":".join([settings.CACHE_KEY_PREFIX, *stringified])

    def get_json(self, key: str, resource: str) -> Optional[Any]:
        if not self._enabled:
            return None

        local_hit, local_value = self._get_local(key, resource)
        if local_hit:
            return local_value

        if self._client is None:
            return None

        try:
            payload = self._client.get(key)
            self._update_pool_metrics()
        except redis.RedisError as exc:
            logger.warning("Redis GET failed for key %s: %s", key, exc)
            return None

        if payload is None:
            _cache_misses.labels(CACHE_BACKEND_LABEL, resource).inc()
            return None

        _cache_hits.labels(CACHE_BACKEND_LABEL, resource).inc()
        try:
            decoded = json.loads(payload)
        except json.JSONDecodeError:
            logger.warning("Failed to decode JSON payload for key %s", key)
            return None

        self._set_local(key, decoded, self._local_ttl, resource)
        return decoded

    def set_json(self, key: str, value: Any, ttl: int, resource: str) -> None:
        if not self._enabled:
            return

        self._set_local(key, value, ttl, resource)

        if self._client is None:
            return

        try:
            payload = json.dumps(value, separators=(",", ":"))
            self._client.setex(key, ttl, payload)
            self._update_pool_metrics()
        except (TypeError, ValueError) as exc:
            logger.warning("Failed to serialize value for cache key %s: %s", key, exc)
        except redis.RedisError as exc:
            logger.warning("Redis SETEX failed for key %s: %s", key, exc)
        else:
            logger.debug("Cached resource %s under key %s for %s seconds", resource, key, ttl)

    def delete(self, key: str) -> None:
        if not self._enabled:
            return

        self._delete_local_prefix(key)

        if self._client is None:
            return

        try:
            self._client.delete(key)
            self._update_pool_metrics()
        except redis.RedisError as exc:
            logger.warning("Redis DELETE failed for key %s: %s", key, exc)

    def increment(self, key: str, ttl: int) -> int:
        if not self._enabled or self._client is None:
            logger.debug("Cache disabled; returning synthetic counter value for %s", key)
            return 1

        try:
            value = self._client.incr(key)
            self._client.expire(key, ttl)
            self._update_pool_metrics()
            return int(value)
        except redis.RedisError as exc:
            logger.warning("Redis INCR/EXPIRE failed for key %s: %s", key, exc)
            return 1

    def delete_prefix(self, prefix: str) -> None:
        if not self._enabled:
            return

        self._delete_local_prefix(prefix)

        if self._client is None:
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
            self._update_pool_metrics()
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
