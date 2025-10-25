"""Application-wide logging configuration utilities."""
from __future__ import annotations

import logging
import logging.config
import os
from pathlib import Path
from typing import Any, Dict

from pythonjsonlogger import jsonlogger


DEFAULT_LOG_LEVEL = "INFO"
DEFAULT_LOG_PATH = "/www/wwwroot/api/chkaf_update/log/garderobus/api.log"



class _JsonFormatter(jsonlogger.JsonFormatter):
    """Custom JSON formatter that preserves order and adds service metadata."""

    def add_fields(self, log_record: Dict[str, Any], record: logging.LogRecord, message_dict: Dict[str, Any]) -> None:
        super().add_fields(log_record, record, message_dict)
        log_record.setdefault("level", record.levelname)
        log_record.setdefault("logger", record.name)
        log_record.setdefault("service", os.getenv("APP_NAME", "garderobus-api"))
        if record.exc_info:
            log_record.setdefault("exc_info", self.formatException(record.exc_info))


def configure_logging() -> None:
    """Configure standard logging with JSON output for observability tools."""

    log_level = os.getenv("LOG_LEVEL", DEFAULT_LOG_LEVEL).upper()
    log_path = Path(os.getenv("LOG_FILE", DEFAULT_LOG_PATH))

    log_path.parent.mkdir(parents=True, exist_ok=True)

    logging_config = {
        "version": 1,
        "disable_existing_loggers": False,
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
            },
            "file": {
                "class": "logging.handlers.TimedRotatingFileHandler",
                "formatter": "json",
                "level": log_level,
                "filename": str(log_path),
                "when": "midnight",
                "backupCount": int(os.getenv("LOG_FILE_BACKUP_COUNT", "7")),
            },
        },
        "root": {
            "handlers": ["console", "file"],
            "level": log_level,
        },
    }

    logging.config.dictConfig(logging_config)


__all__ = ["configure_logging"]
