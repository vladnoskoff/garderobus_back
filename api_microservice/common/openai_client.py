"""Helper utilities for constructing a shared OpenAI client with SOCKS proxy support."""

from functools import lru_cache
from typing import Optional

import httpx
from httpx_socks import SyncProxyTransport
from openai import OpenAI

from . import settings


def _build_http_client() -> Optional[httpx.Client]:
    """Create an httpx client configured with a SOCKS proxy when enabled."""

    if not settings.ENABLE_SOCKS_PROXY:
        return None

    proxy_url = settings.SOCKS_PROXY_URL
    if not proxy_url:
        return None

    transport = SyncProxyTransport.from_url(proxy_url, rdns=True)
    return httpx.Client(transport=transport, timeout=60.0)


@lru_cache(maxsize=1)
def get_openai_client() -> OpenAI:
    """Return a cached OpenAI client that honours the global proxy configuration."""

    api_key = settings.OPENAI_API_KEY
    if not api_key or not api_key.startswith("sk-"):
        raise RuntimeError("Укажи корректный OPENAI_API_KEY (строка, начинающаяся с 'sk-').")

    http_client = _build_http_client()
    if http_client is not None:
        return OpenAI(api_key=api_key, http_client=http_client)

    return OpenAI(api_key=api_key)


def is_proxy_active() -> bool:
    """Return True when SOCKS proxying is configured and enabled."""

    return settings.ENABLE_SOCKS_PROXY and bool(settings.SOCKS_PROXY_URL)
