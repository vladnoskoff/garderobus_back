import json
import logging
import os
import requests
import subprocess
import threading
import signal
import time
import pwd
import grp
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional

from celery.exceptions import CeleryError
from kombu.exceptions import OperationalError
from fastapi import HTTPException, status

from celery_app import celery_app
import models
import settings
import schemas

logger = logging.getLogger(__name__)

_START_TIME = time.time()
_LAST_RESTART_REQUEST: Optional[datetime] = None
_LAST_MAINTENANCE_CHANGE: Optional[datetime] = None
_MAINTENANCE_ENABLED: bool = settings.ADMIN_MAINTENANCE_INITIAL_STATE

LOG_DATE_FORMATS = ("%Y-%m-%d %H:%M:%S,%f", "%Y-%m-%d %H:%M:%S")


def _log_managed_file_error(relative_path: str, detail: str, **extra: object) -> None:
    logger.warning(
        "Managed code operation failed",
        extra={"file": relative_path, "detail": detail, **extra},
    )


def _parse_datetime(value: object) -> Optional[datetime]:
    if not value:
        return None

    if isinstance(value, datetime):
        return value

    if isinstance(value, (int, float)):
        try:
            return datetime.fromtimestamp(value, tz=timezone.utc)
        except (OverflowError, OSError, ValueError):
            return None

    if isinstance(value, str):
        for fmt in (None, "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M:%S.%f"):
            try:
                if fmt:
                    return datetime.strptime(value, fmt).replace(tzinfo=timezone.utc)
                return datetime.fromisoformat(value)
            except ValueError:
                continue

    return None


def _normalize_task_payload(task: dict, state: str, worker: str) -> schemas.AdminQueueTask:
    request = task.get("request") if isinstance(task.get("request"), dict) else {}
    delivery_info = task.get("delivery_info")
    if isinstance(request, dict) and not isinstance(delivery_info, dict):
        delivery_info = request.get("delivery_info")

    queue = None
    if isinstance(delivery_info, dict):
        queue = delivery_info.get("routing_key") or delivery_info.get("queue")

    eta_raw = task.get("eta") or task.get("time_start")
    if isinstance(request, dict) and not eta_raw:
        eta_raw = request.get("eta") or request.get("time_start")

    task_id = (
        task.get("id")
        or task.get("request_id")
        or (request.get("id") if isinstance(request, dict) else None)
        or "unknown"
    )

    name = task.get("name")
    if isinstance(request, dict) and not name:
        name = request.get("name")

    args_repr = task.get("args")
    if isinstance(request, dict) and not args_repr:
        args_repr = request.get("argsrepr") or request.get("args")

    kwargs_repr = task.get("kwargs")
    if isinstance(request, dict) and not kwargs_repr:
        kwargs_repr = request.get("kwargsrepr") or request.get("kwargs")

    return schemas.AdminQueueTask(
        id=str(task_id),
        name=name or "Неизвестная задача",
        state=state,  # type: ignore[arg-type]
        worker=worker,
        queue=queue,
        eta=_parse_datetime(eta_raw),
        args=str(args_repr or ""),
        kwargs=str(kwargs_repr or ""),
    )


def _collect_tasks(tasks_by_worker: dict, state: str) -> list[schemas.AdminQueueTask]:
    normalized: list[schemas.AdminQueueTask] = []
    for worker, tasks in (tasks_by_worker or {}).items():
        if not isinstance(tasks, list):
            continue
        for task in tasks:
            if isinstance(task, dict):
                normalized.append(_normalize_task_payload(task, state, worker))
    return normalized


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
        _log_managed_file_error(relative_path, "Недопустимый путь файла")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Недопустимый путь файла",
        )

    root = settings.ADMIN_MANAGED_CODE_ROOT.resolve()
    full_path = (root / candidate).resolve()

    if not str(full_path).startswith(str(root)):
        _log_managed_file_error(
            relative_path, "Путь выходит за пределы разрешенной директории"
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Путь выходит за пределы разрешенной директории",
        )

    if not _allowed_extension(full_path):
        _log_managed_file_error(relative_path, "Расширение не поддерживается")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Расширение файла не поддерживается для редактирования",
        )

    return full_path


def _validate_size(content: str, *, path: str = "(unknown)") -> None:
    max_size = settings.ADMIN_MANAGED_CODE_MAX_SIZE
    if max_size and len(content.encode("utf-8")) > max_size:
        _log_managed_file_error(
            path,
            "Размер файла превышает допустимый предел",
            size=len(content.encode("utf-8")),
        )
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Размер файла превышает допустимый предел",
        )


def _content_matches(full_path: Path, expected: str) -> bool:
    try:
        return full_path.read_text(encoding="utf-8") == expected
    except OSError:
        return False


def _is_ignored_path(path: Path) -> bool:
    if any(part == "__pycache__" for part in path.parts):
        return True

    if path.suffix.lower() in {".pyc", ".pyo"}:
        return True

    return False


def _permission_remediation(full_path: Path, *, process_user: str, process_group: str) -> str:
    suggestions: list[str] = []

    try:
        file_stat = full_path.stat()
    except OSError:
        file_stat = None

    try:
        parent_stat = full_path.parent.stat()
    except OSError:
        parent_stat = None

    if not os.access(full_path, os.W_OK):
        suggestions.append(f"sudo chmod u+w {full_path}")

    if parent_stat and not os.access(full_path.parent, os.W_OK):
        suggestions.append(f"sudo chmod u+w {full_path.parent}")

    if file_stat and (file_stat.st_uid != os.geteuid() or file_stat.st_gid != os.getegid()):
        suggestions.append(
            f"sudo chown {process_user}:{process_group} {full_path}"
        )

    if not suggestions:
        return ""

    return " Возможные действия: " + "; ".join(suggestions) + "."


def list_managed_files() -> List[str]:
    root = settings.ADMIN_MANAGED_CODE_ROOT
    if not root.exists():
        return []

    files: List[str] = []
    for file_path in root.rglob("*"):
        if not file_path.is_file():
            continue
        if _is_ignored_path(file_path):
            continue
        if not _allowed_extension(file_path):
            continue
        try:
            relative = file_path.relative_to(root).as_posix()
        except ValueError:
            continue
        files.append(relative)

    files.sort(key=str.casefold)
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


def get_queue_snapshot() -> schemas.AdminQueueSnapshot:
    inspector = celery_app.control.inspect(timeout=1.0)

    try:
        active = inspector.active() or {}
        reserved = inspector.reserved() or {}
        scheduled = inspector.scheduled() or {}
    except (CeleryError, OperationalError, ConnectionError) as exc:  # pragma: no cover - network / broker issues
        logger.warning("Failed to fetch Celery queue snapshot: %s", exc)
        return schemas.AdminQueueSnapshot(
            total=0,
            by_state={"active": 0, "reserved": 0, "scheduled": 0},
            tasks=[],
            broker_available=False,
            error="Не удалось получить состояние очереди Celery",
        )

    active_tasks = _collect_tasks(active, "active")
    reserved_tasks = _collect_tasks(reserved, "reserved")
    scheduled_tasks = _collect_tasks(scheduled, "scheduled")

    all_tasks = active_tasks + reserved_tasks + scheduled_tasks
    by_state = {
        "active": len(active_tasks),
        "reserved": len(reserved_tasks),
        "scheduled": len(scheduled_tasks),
    }

    return schemas.AdminQueueSnapshot(
        total=sum(by_state.values()),
        by_state=by_state,
        tasks=all_tasks,
        broker_available=True,
    )


def read_managed_file(relative_path: str) -> schemas.AdminCodeFile:
    full_path = _ensure_within_root(relative_path)
    if not full_path.exists() or not full_path.is_file():
        _log_managed_file_error(relative_path, "Файл не найден")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Файл не найден",
        )

    try:
        content = full_path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        _log_managed_file_error(
            relative_path, "Файл не может быть прочитан как текст UTF-8"
        )
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Файл не может быть прочитан как текст UTF-8",
        ) from exc
    except OSError as exc:
        _log_managed_file_error(relative_path, "Не удалось прочитать файл", error=str(exc))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Не удалось прочитать файл",
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
        _log_managed_file_error(relative_path, "Файл не найден")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Файл не найден",
        )

    _validate_size(content, path=relative_path)

    try:
        full_path.write_text(content, encoding="utf-8")
    except PermissionError as exc:
        if _content_matches(full_path, content):
            logger.warning(
                "Write reported permission error but content matches. Returning success.",
                extra={"file": relative_path, "error": str(exc)},
            )
        else:
            stat = full_path.stat()

            try:
                owner = pwd.getpwuid(stat.st_uid).pw_name
            except KeyError:
                owner = str(stat.st_uid)

            try:
                group = grp.getgrgid(stat.st_gid).gr_name
            except KeyError:
                group = str(stat.st_gid)

            process_user = pwd.getpwuid(os.geteuid()).pw_name
            process_group = grp.getgrgid(os.getegid()).gr_name
            mode = oct(stat.st_mode & 0o777)

            remediation = _permission_remediation(
                full_path, process_user=process_user, process_group=process_group
            )

            detail = (
                "Недостаточно прав для сохранения файла. "
                "Файл принадлежит {owner}:{group} с правами {mode}; "
                "API запущен от {user}:{proc_group}. "
                "Сохранение всегда выполняется от имени процесса API — даже если вы редактируете код от другого пользователя. "
                "Дайте доступ на запись (например, chown/chmod) или сохраните файл от имени владельца." + remediation
            ).format(owner=owner, group=group, mode=mode, user=process_user, proc_group=process_group)

            _log_managed_file_error(
                relative_path,
                detail,
                error=str(exc),
                owner=owner,
                group=group,
                mode=mode,
                process_user=process_user,
                process_group=process_group,
                remediation=remediation.strip(),
            )

            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=detail,
            ) from exc
    except OSError as exc:
        if _content_matches(full_path, content):
            logger.warning(
                "Write reported error but content matches. Returning success.",
                extra={"file": relative_path, "error": str(exc)},
            )
        else:
            _log_managed_file_error(
                relative_path, "Не удалось сохранить файл", error=str(exc)
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Не удалось сохранить файл",
            ) from exc
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


def _schedule_self_restart(delay: float = 0.5) -> None:
    def _shutdown() -> None:
        time.sleep(delay)
        try:
            os.kill(os.getpid(), signal.SIGTERM)
        finally:
            os._exit(0)

    threading.Thread(target=_shutdown, daemon=True).start()


def is_restart_supported() -> bool:
    return bool(settings.ADMIN_ALLOW_RESTART)


def is_worker_restart_supported() -> bool:
    return bool(settings.ADMIN_ALLOW_WORKER_RESTART and settings.ADMIN_WORKER_RESTART_COMMAND)


def restart_api(*, requested_by: Optional[models.User] = None) -> schemas.AdminRestartResponse:
    if not settings.ADMIN_ALLOW_RESTART:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Перезапуск API не настроен",
        )

    command = (settings.ADMIN_RESTART_COMMAND or "").strip()

    logger.info(
        "API restart requested",
        extra={
            "actor_id": getattr(requested_by, "id", None),
            "actor_email": getattr(requested_by, "email", None),
            "command": command,
        },
    )

    process = None
    if command:
        try:
            process = subprocess.Popen(  # noqa: S603 - administrative action
                command,  # noqa: S607 - command configured by environment
                shell=True,
            )
        except OSError as exc:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Не удалось инициировать перезапуск API",
            ) from exc
    else:
        _schedule_self_restart()

    global _LAST_RESTART_REQUEST
    _LAST_RESTART_REQUEST = datetime.now(timezone.utc)

    return schemas.AdminRestartResponse(
        detail=(
            "Перезапуск API инициирован"
            if command
            else "Перезапуск API инициирован (автоматическое завершение процесса)"
        ),
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

    def _detect_event_category() -> str:
        raw_service = str(payload.get("service") or "").lower()
        raw_logger = str(payload.get("logger") or payload.get("name") or "").lower()
        raw_message = message.lower()

        context = payload.get("context") or {}
        context_text = " ".join(
            str(value) for value in context.values() if isinstance(value, (str, int, float))
        ).lower()

        searchable = " ".join(
            part for part in [raw_service, raw_logger, raw_message, context_text] if part
        )

        def has_any(text: str, tokens: tuple[str, ...]) -> bool:
            return any(token in text for token in tokens)

        if has_any(searchable, ("xray", "vpn", "socks", "proxy")):
            return "xray"

        if has_any(
            searchable,
            (
                "db",
                "database",
                "postgres",
                "psql",
                "sqlalchemy",
                "mysql",
                "sqlite",
                "psycopg",
                "query",
                "pool",
            ),
        ):
            return "database"

        if has_any(
            searchable,
            ("uvicorn", "fastapi", "http", "api", "request", "endpoint", "gunicorn"),
        ):
            return "api"

        if has_any(
            searchable,
            (
                "celery",
                "worker",
                "queue",
                "task",
                "beat",
                "redis",
                "amqp",
                "rabbit",
                "kombu",
            ),
        ):
            return "workers"

        return "application"

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
        category=_detect_event_category(),
        context=context,
    )


def _build_plain_event(line: str) -> Optional[schemas.AdminSystemEvent]:
    for fmt in LOG_DATE_FORMATS:
        fmt_normalized = fmt.replace(",%f", ".%f")
        try:
            parsed = datetime.strptime(line[: len(fmt_normalized)], fmt_normalized)
            timestamp = parsed.replace(tzinfo=timezone.utc)
            remainder = line[len(fmt_normalized) :].strip(" -:")
            break
        except ValueError:
            timestamp = None
    else:
        timestamp = None

    if timestamp is None:
        return None

    level = "info"
    lowered = line.lower()
    if any(token in lowered for token in ("error", "err")):
        level = "error"
    elif "warn" in lowered:
        level = "warning"
    elif "debug" in lowered:
        level = "debug"

    message = remainder if remainder else line.strip()
    payload = {"timestamp": timestamp, "level": level, "message": message}
    return _build_event(payload)


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
                event = _build_plain_event(line)
                if event is None:
                    continue
                if desired_level and event.level != desired_level:
                    continue
                if cutoff and event.timestamp < cutoff:
                    continue
                events.append(event)
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
