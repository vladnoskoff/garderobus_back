"""Application-wide logging configuration utilities."""
from __future__ import annotations

import logging
import logging.config
import os
from contextvars import ContextVar, Token
from pathlib import Path
from typing import Any, Dict, Iterable, Mapping

from pythonjsonlogger import jsonlogger


DEFAULT_LOG_LEVEL = "INFO"
DEFAULT_LOG_PATH = "/www/wwwroot/api/chkaf_update/log/garderobus/api.log"


_REQUEST_ID: ContextVar[str | None] = ContextVar("request_id", default=None)
_TRACE_ID: ContextVar[str | None] = ContextVar("trace_id", default=None)
_MASKED_KEYS = {"password", "token", "refresh_token", "access_token", "authorization"}



class _JsonFormatter(jsonlogger.JsonFormatter):
    """Custom JSON formatter that preserves order and adds service metadata."""

    def add_fields(self, log_record: Dict[str, Any], record: logging.LogRecord, message_dict: Dict[str, Any]) -> None:
        super().add_fields(log_record, record, message_dict)
        log_record.setdefault("level", record.levelname)
        log_record.setdefault("logger", record.name)
        log_record.setdefault("service", os.getenv("APP_NAME", "garderobus-api"))
        log_record.setdefault("request_id", getattr(record, "request_id", None))
        log_record.setdefault("trace_id", getattr(record, "trace_id", None))
        if record.exc_info:
            log_record.setdefault("exc_info", self.formatException(record.exc_info))


class _RequestContextFilter(logging.Filter):
    """Inject request and trace identifiers into every log record."""

    def filter(self, record: logging.LogRecord) -> bool:  # noqa: A003 - standard signature
        record.request_id = _REQUEST_ID.get()
        record.trace_id = _TRACE_ID.get()
        return True


def set_request_context(*, request_id: str | None, trace_id: str | None = None) -> tuple[Token, Token]:
    """Expose context setters for middleware to propagate request metadata."""

    request_token = _REQUEST_ID.set(request_id)
    trace_token = _TRACE_ID.set(trace_id)
    return request_token, trace_token


def reset_request_context(*tokens: Token) -> None:
    """Reset previously stored request context values."""

    for var, token in zip((_REQUEST_ID, _TRACE_ID), tokens, strict=False):
        var.reset(token)


def mask_sensitive_data(payload: Mapping[str, Any] | None) -> Dict[str, Any]:
    """Return a shallow copy with sensitive keys masked for safe logging."""

    if payload is None:
        return {}

    sanitized: Dict[str, Any] = {}
    for key, value in payload.items():
        if key.lower() in _MASKED_KEYS:
            sanitized[key] = "***"
        elif isinstance(value, Mapping):
            sanitized[key] = mask_sensitive_data(value)
        elif isinstance(value, Iterable) and not isinstance(value, (str, bytes)):
            sanitized[key] = [mask_sensitive_data(item) if isinstance(item, Mapping) else item for item in value]
        else:
            sanitized[key] = value

    return sanitized


def configure_logging() -> None:
    """Configure standard logging with JSON output for observability tools."""

    log_level = os.getenv("LOG_LEVEL", DEFAULT_LOG_LEVEL).upper()
    log_path = Path(os.getenv("LOG_FILE", DEFAULT_LOG_PATH))

    log_path.parent.mkdir(parents=True, exist_ok=True)

    logging_config = {
        "version": 1,
        "disable_existing_loggers": False,
        "filters": {"request_context": {"()": _RequestContextFilter}},
        "formatters": {
            "json": {
                "()": _JsonFormatter,
                "fmt": "%(asctime)s %(levelname)s %(name)s %(message)s",
            },
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "formatter": "json",
                "level": log_level,
                "filters": ["request_context"],
            },
            "file": {
                "class": "logging.handlers.TimedRotatingFileHandler",
                "formatter": "json",
                "level": log_level,
                "filename": str(log_path),
                "when": "midnight",
                "backupCount": int(os.getenv("LOG_FILE_BACKUP_COUNT", "7")),
                "filters": ["request_context"],
            },
        },
        "root": {
            "handlers": ["console", "file"],
            "level": log_level,
        },
    }

    logging.config.dictConfig(logging_config)


__all__ = [
    "configure_logging",
    "mask_sensitive_data",
    "reset_request_context",
    "set_request_context",
]
