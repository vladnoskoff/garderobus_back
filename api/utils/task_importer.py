from __future__ import annotations

from importlib import import_module
import importlib.util
import logging
from pathlib import Path
import sys
from types import ModuleType
from typing import Iterable, Sequence

from fastapi import HTTPException, status

DEFAULT_MODULE_PATHS: tuple[str, ...] = ("tasks.ai", "api.tasks.ai")


def _ensure_sys_path(api_dir: Path) -> None:
    project_root = api_dir.parent

    for path in (api_dir, project_root):
        path_str = str(path)
        if path_str not in sys.path:
            sys.path.insert(0, path_str)


def _missing_attributes(module: ModuleType, required: Iterable[str]) -> list[str]:
    return [attr for attr in required if not hasattr(module, attr)]


def load_tasks_module(
    *,
    required_attrs: Sequence[str],
    api_dir: Path,
    logger: logging.Logger,
    module_paths: Sequence[str] = DEFAULT_MODULE_PATHS,
    fallback_file: Path | None = None,
) -> ModuleType:
    """Load the Celery tasks module with consistent path handling and validation."""

    _ensure_sys_path(api_dir)

    attempts: list[dict[str, object]] = []
    last_exc: ImportError | None = None

    for module_path in module_paths:
        try:
            module = import_module(module_path)
        except ImportError as exc:
            attempts.append({"module": module_path, "error": str(exc)})
            last_exc = exc
            continue

        missing = _missing_attributes(module, required_attrs)
        if missing:
            attempts.append(
                {
                    "module": module_path,
                    "error": "missing required attributes",
                    "missing": missing,
                    "file": getattr(module, "__file__", "<unknown>"),
                }
            )
            logger.error("Tasks module missing callables", extra={"attempts": attempts})
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"AI задачи недоступны: отсутствуют {', '.join(missing)}",
            )

        return module

    if fallback_file and fallback_file.exists():
        spec = importlib.util.spec_from_file_location(fallback_file.stem, fallback_file)
        if spec and spec.loader:
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            missing = _missing_attributes(module, required_attrs)
            if missing:
                attempts.append(
                    {
                        "module": str(fallback_file),
                        "error": "missing required attributes",
                        "missing": missing,
                        "file": str(fallback_file),
                    }
                )
                logger.error("Tasks module missing callables", extra={"attempts": attempts})
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"AI задачи недоступны: отсутствуют {', '.join(missing)}",
                )

            return module

    logger.error("AI tasks module import failed", extra={"attempts": attempts})
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="AI задачи недоступны (проверьте PYTHONPATH и установку api)",
    ) from last_exc