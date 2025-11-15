"""HTTP client wrapper with rate limiting, circuit breaker and timeouts."""
from __future__ import annotations

import logging
import threading
import time
from collections import defaultdict, deque
from typing import Any, Deque, Dict, Optional

import requests
from pybreaker import CircuitBreaker, CircuitBreakerError

from . import settings

logger = logging.getLogger(__name__)


class RateLimitExceededError(Exception):
    """Raised when the configured rate limit is exceeded."""


class ExternalServiceError(Exception):
    """Base exception for errors originating from external services."""


class CircuitOpenError(ExternalServiceError):
    """Raised when the circuit breaker is open for the target service."""


class HTTPRequestError(ExternalServiceError):
    """Raised when the HTTP request fails for networking reasons."""


class SlidingWindowRateLimiter:
    """Simple sliding window rate limiter shared across threads."""

    def __init__(self, max_calls: int, period: float) -> None:
        self.max_calls = max_calls
        self.period = period
        self._timestamps: Deque[float] = deque()
        self._lock = threading.Lock()

    def acquire(self) -> None:
        with self._lock:
            now = time.monotonic()
            while self._timestamps and now - self._timestamps[0] > self.period:
                self._timestamps.popleft()

            if len(self._timestamps) >= self.max_calls:
                raise RateLimitExceededError(
                    f"Exceeded rate limit of {self.max_calls} calls per {self.period} seconds"
                )

            self._timestamps.append(now)


class ResilientHTTPClient:
    """Encapsulates resiliency patterns for outgoing HTTP requests."""

    def __init__(self) -> None:
        self._breakers: Dict[str, CircuitBreaker] = {}
        self._limiters: Dict[str, SlidingWindowRateLimiter] = defaultdict(self._build_rate_limiter)
        self._lock = threading.Lock()

    def _build_rate_limiter(self) -> SlidingWindowRateLimiter:
        return SlidingWindowRateLimiter(
            settings.HTTP_CLIENT_RATE_LIMIT,
            settings.HTTP_CLIENT_RATE_PERIOD,
        )

    def _get_breaker(self, service_name: str) -> CircuitBreaker:
        with self._lock:
            if service_name not in self._breakers:
                self._breakers[service_name] = CircuitBreaker(
                    fail_max=settings.HTTP_CLIENT_CIRCUIT_MAX_FAILURES,
                    reset_timeout=settings.HTTP_CLIENT_CIRCUIT_RESET_TIMEOUT,
                    name=f"http-{service_name}",
                )
            return self._breakers[service_name]

    def request(self, method: str, url: str, *, service_name: str, timeout: Optional[float] = None, **kwargs: Any) -> requests.Response:
        timeout = timeout or settings.HTTP_CLIENT_TIMEOUT
        breaker = self._get_breaker(service_name)
        limiter = self._limiters[service_name]

        try:
            limiter.acquire()
        except RateLimitExceededError as exc:
            logger.warning("Outgoing HTTP rate limit hit", extra={"service": service_name, "url": url})
            raise

        try:
            response: requests.Response = breaker.call(
                requests.request,
                method,
                url,
                timeout=timeout,
                **kwargs,
            )
        except CircuitBreakerError as exc:
            logger.error("Circuit breaker open", extra={"service": service_name, "url": url})
            raise CircuitOpenError(str(exc)) from exc
        except requests.Timeout as exc:
            logger.warning("HTTP request timeout", extra={"service": service_name, "url": url, "timeout": timeout})
            raise HTTPRequestError("Timeout during HTTP request") from exc
        except requests.RequestException as exc:
            logger.exception("HTTP request error", extra={"service": service_name, "url": url})
            raise HTTPRequestError(str(exc)) from exc

        return response

    def get(self, url: str, *, service_name: str, timeout: Optional[float] = None, **kwargs: Any) -> requests.Response:
        return self.request("GET", url, service_name=service_name, timeout=timeout, **kwargs)

    def post(self, url: str, *, service_name: str, timeout: Optional[float] = None, **kwargs: Any) -> requests.Response:
        return self.request("POST", url, service_name=service_name, timeout=timeout, **kwargs)


http_client = ResilientHTTPClient()

__all__ = [
    "http_client",
    "ResilientHTTPClient",
    "RateLimitExceededError",
    "ExternalServiceError",
    "CircuitOpenError",
    "HTTPRequestError",
]
