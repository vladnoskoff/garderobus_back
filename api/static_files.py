"""Static files helpers that add HTTP cache headers and CDN hints."""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Optional

from fastapi.responses import Response
from fastapi.staticfiles import StaticFiles


class CDNStaticFiles(StaticFiles):
    """Static files handler that adds Cache-Control headers and ETags."""

    def __init__(
        self,
        *args,
        cache_control: Optional[str] = None,
        cdn_cache_control: Optional[str] = None,
        enable_etag: bool = True,
        **kwargs,
    ) -> None:
        super().__init__(*args, **kwargs)
        self._cache_control = cache_control
        self._cdn_cache_control = cdn_cache_control
        self._enable_etag = enable_etag

    async def get_response(self, path: str, scope) -> Response:
        response = await super().get_response(path, scope)

        if response.status_code != 200:
            return response

        etag: Optional[str] = None
        if self._enable_etag:
            etag = self._build_etag(path)
            if etag:
                request_etag = self._extract_if_none_match(scope)
                if request_etag and request_etag == etag:
                    headers = self._build_headers(etag)
                    return Response(status_code=304, headers=headers)
                response.headers["ETag"] = etag

        self._apply_cache_headers(response, etag)
        return response

    def _apply_cache_headers(self, response: Response, etag: Optional[str]) -> None:
        if self._cache_control:
            response.headers.setdefault("Cache-Control", self._cache_control)
        if self._cdn_cache_control:
            response.headers["CDN-Cache-Control"] = self._cdn_cache_control
        if etag:
            response.headers.setdefault("ETag", etag)

    def _build_headers(self, etag: str) -> dict[str, str]:
        headers: dict[str, str] = {}
        if self._cache_control:
            headers["Cache-Control"] = self._cache_control
        if self._cdn_cache_control:
            headers["CDN-Cache-Control"] = self._cdn_cache_control
        headers["ETag"] = etag
        return headers

    def _build_etag(self, relative_path: str) -> Optional[str]:
        try:
            full_path = Path(self.directory) / relative_path
            stat_result = full_path.stat()
        except FileNotFoundError:
            return None

        fingerprint = f"{stat_result.st_mtime_ns}:{stat_result.st_size}".encode("utf-8")
        digest = hashlib.sha1(fingerprint).hexdigest()
        return f'W/"{digest}"'

    @staticmethod
    def _extract_if_none_match(scope) -> Optional[str]:
        for raw_name, raw_value in scope.get("headers", []):
            if raw_name.decode("latin1").lower() == "if-none-match":
                return raw_value.decode("latin1")
        return None
