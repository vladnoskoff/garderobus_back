import json
import logging
import os
import requests
import subprocess
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional

from fastapi import HTTPException, status

import models
import settings
import schemas

logger = logging.getLogger(__name__)

_START_TIME = time.time()
_LAST_RESTART_REQUEST: Optional[datetime] = None
_LAST_MAINTENANCE_CHANGE: Optional[datetime] = None
_MAINTENANCE_ENABLED: bool = settings.ADMIN_MAINTENANCE_INITIAL_STATE

LOG_DATE_FORMATS = ("%Y-%m-%d %H:%M:%S,%f", "%Y-%m-%d %H:%M:%S")

LOG_DATE_FORMATS = ("%Y-%m-%d %H:%M:%S,%f", "%Y-%m-%d %H:%M:%S")


def _humanize_duration(seconds: float) -> str:
    seconds = max(0, int(seconds))
    days, remainder = divmod(seconds, 86400)
    hours, remainder = divmod(remainder, 3600)
    minutes, seconds = divmod(remainder, 60)

    parts: List[str] = []
    if days:
        parts.append(f"{days} д")
    if hours:
        parts.append(f"{hours} ч")
    if minutes:
        parts.append(f"{minutes} мин")
    if seconds or not parts:
        parts.append(f"{seconds} с")

    return " ".join(parts)


def _allowed_extension(path: Path) -> bool:
    if not settings.ADMIN_MANAGED_CODE_EXTENSIONS:
        return True
    return path.suffix.lower() in settings.ADMIN_MANAGED_CODE_EXTENSIONS


def _ensure_within_root(relative_path: str) -> Path:
    candidate = Path(relative_path)
    if candidate.is_absolute() or any(part == ".." for part in candidate.parts):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Недопустимый путь файла",
        )

    root = settings.ADMIN_MANAGED_CODE_ROOT.resolve()
    full_path = (root / candidate).resolve()

    if not str(full_path).startswith(str(root)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Путь выходит за пределы разрешенной директории",
        )

    if not _allowed_extension(full_path):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Расширение файла не поддерживается для редактирования",
        )

    return full_path


def _validate_size(content: str) -> None:
    max_size = settings.ADMIN_MANAGED_CODE_MAX_SIZE
    if max_size and len(content.encode("utf-8")) > max_size:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Размер файла превышает допустимый предел",
        )


def list_managed_files() -> List[str]:
    root = settings.ADMIN_MANAGED_CODE_ROOT
    if not root.exists():
        return []

    files: List[str] = []
    for file_path in root.rglob("*"):
        if not file_path.is_file():
            continue
        if not _allowed_extension(file_path):
            continue
        try:
            relative = file_path.relative_to(root).as_posix()
        except ValueError:
            continue
        files.append(relative)

    files.sort()
    return files


def get_system_status() -> schemas.AdminSystemStatus:
    uptime_seconds = time.time() - _START_TIME
    return schemas.AdminSystemStatus(
        uptime_seconds=uptime_seconds,
        uptime_human=_humanize_duration(uptime_seconds),
        restart_supported=is_restart_supported(),
        worker_restart_supported=is_worker_restart_supported(),
        last_restart_requested_at=_LAST_RESTART_REQUEST,
        managed_files=list_managed_files(),
        app_name=settings.APP_NAME,
        app_version=settings.APP_VERSION,
        environment=settings.APP_ENV,
        maintenance_enabled=_MAINTENANCE_ENABLED,
        maintenance_supported=is_maintenance_supported(),
        test_webhook_configured=bool(settings.ADMIN_TEST_WEBHOOK_URL),
    )


def read_managed_file(relative_path: str) -> schemas.AdminCodeFile:
    full_path = _ensure_within_root(relative_path)
    if not full_path.exists() or not full_path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Файл не найден",
        )

    try:
        content = full_path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Файл не может быть прочитан как текст UTF-8",
        ) from exc

    relative = full_path.relative_to(settings.ADMIN_MANAGED_CODE_ROOT).as_posix()
    return schemas.AdminCodeFile(path=relative, content=content)


def write_managed_file(
    relative_path: str,
    content: str,
    *,
    message: Optional[str] = None,
    actor: Optional[models.User] = None,
) -> schemas.AdminCodeFile:
    full_path = _ensure_within_root(relative_path)
    if not full_path.exists() or not full_path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Файл не найден",
        )

    _validate_size(content)

    full_path.write_text(content, encoding="utf-8")
    relative = full_path.relative_to(settings.ADMIN_MANAGED_CODE_ROOT).as_posix()

    logger.info(
        "Managed code file updated",
        extra={
            "file": relative,
            "actor_id": getattr(actor, "id", None),
            "actor_email": getattr(actor, "email", None),
            "message": message,
        },
    )

    return schemas.AdminCodeFile(path=relative, content=content)


def is_restart_supported() -> bool:
    return bool(settings.ADMIN_ALLOW_RESTART and settings.ADMIN_RESTART_COMMAND)


def is_worker_restart_supported() -> bool:
    return bool(settings.ADMIN_ALLOW_WORKER_RESTART and settings.ADMIN_WORKER_RESTART_COMMAND)


def restart_api(*, requested_by: Optional[models.User] = None) -> schemas.AdminRestartResponse:
    if not is_restart_supported():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Перезапуск API не настроен",
        )

    command = settings.ADMIN_RESTART_COMMAND
    if not command:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Команда перезапуска не задана",
        )

    logger.info(
        "API restart requested",
        extra={
            "actor_id": getattr(requested_by, "id", None),
            "actor_email": getattr(requested_by, "email", None),
            "command": command,
        },
    )

    sanitized_command = command.strip()

    try:
        process = subprocess.Popen(  # noqa: S603 - administrative action
            sanitized_command,  # noqa: S607 - command configured by environment
            shell=True,
        )
    except OSError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Не удалось инициировать перезапуск API",
        ) from exc

    global _LAST_RESTART_REQUEST
    _LAST_RESTART_REQUEST = datetime.now(timezone.utc)

    return schemas.AdminRestartResponse(
        detail="Перезапуск API инициирован",
        pid=getattr(process, "pid", None),
    )


def restart_workers(*, requested_by: Optional[models.User] = None) -> schemas.AdminActionResponse:
    if not is_worker_restart_supported():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Перезапуск воркеров не настроен",
        )

    command = settings.ADMIN_WORKER_RESTART_COMMAND
    logger.info(
        "Worker restart requested",
        extra={
            "actor_id": getattr(requested_by, "id", None),
            "actor_email": getattr(requested_by, "email", None),
            "command": command,
        },
    )

    try:
        result = subprocess.run(  # noqa: S603 - administrative action
            command,  # noqa: S607 - command from environment
            shell=True,
            check=False,
            capture_output=True,
            text=True,
            env=os.environ.copy(),
        )
    except OSError as exc:  # pragma: no cover - system-specific failure
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Не удалось выполнить команду перезапуска воркеров",
        ) from exc

    if result.returncode != 0:
        detail = result.stderr or result.stdout or "Команда завершилась с ошибкой"
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=detail,
        )

    return schemas.AdminActionResponse(
        detail="Перезапуск фоновых воркеров инициирован",
        success=True,
    )


def is_maintenance_supported() -> bool:
    return bool(
        settings.ADMIN_MAINTENANCE_ENABLE_COMMAND
        and settings.ADMIN_MAINTENANCE_DISABLE_COMMAND
    )


def set_maintenance_mode(
    *, enabled: bool, requested_by: Optional[models.User] = None
) -> schemas.AdminActionResponse:
    if not is_maintenance_supported():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Команды maintenance не настроены",
        )

    command = (
        settings.ADMIN_MAINTENANCE_ENABLE_COMMAND
        if enabled
        else settings.ADMIN_MAINTENANCE_DISABLE_COMMAND
    )

    logger.info(
        "Maintenance toggle requested",
        extra={
            "actor_id": getattr(requested_by, "id", None),
            "actor_email": getattr(requested_by, "email", None),
            "enabled": enabled,
            "command": command,
        },
    )

    try:
        result = subprocess.run(  # noqa: S603 - administrative action
            command,  # noqa: S607 - command from environment
            shell=True,
            check=False,
            capture_output=True,
            text=True,
            env=os.environ.copy(),
        )
    except OSError as exc:  # pragma: no cover - system-specific failure
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Не удалось применить maintenance режим",
        ) from exc

    if result.returncode != 0:
        detail = result.stderr or result.stdout or "Команда завершилась с ошибкой"
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=detail,
        )

    global _MAINTENANCE_ENABLED, _LAST_MAINTENANCE_CHANGE
    _MAINTENANCE_ENABLED = enabled
    _LAST_MAINTENANCE_CHANGE = datetime.now(timezone.utc)

    return schemas.AdminActionResponse(
        detail=(
            "Maintenance режим включен" if enabled else "Maintenance режим выключен"
        ),
        success=True,
    )


def send_test_webhook(
    *, requested_by: Optional[models.User] = None
) -> schemas.AdminActionResponse:
    if not settings.ADMIN_TEST_WEBHOOK_URL:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="URL тестового webhook не настроен",
        )

    payload = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event": "admin_test_ping",
        "actor_id": getattr(requested_by, "id", None),
        "actor_email": getattr(requested_by, "email", None),
        "message": "Тестовый webhook от панели администратора",
    }

    try:
        response = requests.post(
            settings.ADMIN_TEST_WEBHOOK_URL,
            json=payload,
            timeout=10,
        )
    except requests.RequestException as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Не удалось отправить тестовый webhook",
        ) from exc

    if response.status_code >= 400:
        detail = response.text or f"Webhook ответил со статусом {response.status_code}"
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=detail,
        )

    return schemas.AdminActionResponse(
        detail="Тестовый webhook успешно отправлен",
        success=True,
    )


def _parse_timestamp(raw: Optional[str]) -> Optional[datetime]:
    if not raw:
        return None

    for fmt in LOG_DATE_FORMATS:
        try:
            parsed = datetime.strptime(raw, fmt)
            return parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            continue

    try:
        parsed = datetime.fromisoformat(raw)
    except ValueError:
        return None

    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def _build_event(payload: dict) -> Optional[schemas.AdminSystemEvent]:
    timestamp = _parse_timestamp(
        payload.get("asctime")
        or payload.get("timestamp")
        or payload.get("time")
        or payload.get("@timestamp")
    )
    if timestamp is None:
        return None

    level = str(
        payload.get("level") or payload.get("levelname") or payload.get("severity", "info")
    ).lower()
    message = str(payload.get("message") or payload.get("msg") or "").strip()

    known_keys = {
        "asctime",
        "timestamp",
        "time",
        "@timestamp",
        "level",
        "levelname",
        "severity",
        "message",
        "msg",
        "logger",
        "name",
        "service",
    }

    context = {key: value for key, value in payload.items() if key not in known_keys}

    return schemas.AdminSystemEvent(
        timestamp=timestamp,
        level=level,
        message=message or "—",
        logger=payload.get("logger") or payload.get("name"),
        service=payload.get("service"),
        context=context,
    )


def get_system_events(
    *,
    level: Optional[str] = None,
    hours: Optional[int] = None,
    limit: int = 50,
    page: int = 1,
) -> schemas.AdminSystemEventList:
    log_path = Path(settings.LOG_FILE)
    if not log_path.exists() or not log_path.is_file():
        return schemas.AdminSystemEventList(events=[], total=0, page=page, limit=limit)

    cutoff = None
    if hours is not None and hours > 0:
        cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)

    desired_level = level.lower() if level else None
    events: list[schemas.AdminSystemEvent] = []

    with log_path.open("r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            if not line.strip():
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                continue

            event = _build_event(payload)
            if event is None:
                continue

            if desired_level and event.level != desired_level:
                continue

            if cutoff and event.timestamp < cutoff:
                continue

            events.append(event)

    events.sort(key=lambda item: item.timestamp, reverse=True)

    start = max(0, (page - 1) * limit)
    end = start + limit
    paginated = events[start:end]

    return schemas.AdminSystemEventList(
        events=paginated,
        total=len(events),
        page=page,
        limit=limit,
    )
