"""Integration-like tests for Celery task orchestration primitives."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

API_PATH = Path(__file__).resolve().parents[2] / "api"
if str(API_PATH) not in sys.path:
    sys.path.append(str(API_PATH))

import settings
from celery_app import IdempotentTask, celery_app


CALL_TRACKER = {"count": 0}


@pytest.fixture(autouse=True)
def configure_celery(monkeypatch):
    """Run Celery tasks synchronously with an in-memory backend for tests."""

    celery_app.conf.task_always_eager = True
    celery_app.conf.task_store_eager_result = True
    celery_app.conf.result_backend = "cache+memory://"
    yield


@pytest.fixture()
def call_counter():
    CALL_TRACKER["count"] = 0
    return CALL_TRACKER


@celery_app.task(
    bind=True,
    base=IdempotentTask,
    autoretry_for=(RuntimeError,),
    retry_backoff=True,
    retry_jitter=True,
    retry_kwargs={"max_retries": settings.CELERY_MAX_RETRIES},
    name="tests.unstable_task",
)
def unstable_task(self, fail_until: int, counter: dict[str, int]):  # type: ignore[override]
    CALL_TRACKER["count"] += 1
    if CALL_TRACKER["count"] <= fail_until:
        raise RuntimeError("boom")
    return {"calls": CALL_TRACKER["count"]}


def test_idempotent_task_reuses_cached_result(call_counter):
    first = unstable_task.apply_async(
        kwargs={"fail_until": 0, "counter": call_counter}, idempotency_key="user-1"
    ).get()
    second = unstable_task.apply_async(
        kwargs={"fail_until": 0, "counter": call_counter}, idempotency_key="user-1"
    ).get()

    assert first == second == {"calls": 1}
    assert CALL_TRACKER["count"] == 1


def test_task_dead_letter_emitted_after_retries(call_counter, monkeypatch):
    sent_payload = {}

    def fake_send_task(name, args=None, queue=None, **kwargs):  # pragma: no cover - passthrough
        sent_payload.update({"name": name, "args": args, "queue": queue, **kwargs})
        # Execute locally to make assertions deterministic in eager mode.
        task_name, payload = name, args[0]
        result = celery_app.tasks[task_name].apply(args=[payload])
        return result

    monkeypatch.setattr(unstable_task.app, "send_task", fake_send_task)

    with pytest.raises(RuntimeError):
        unstable_task.apply_async(
            kwargs={"fail_until": settings.CELERY_MAX_RETRIES + 1, "counter": call_counter},
            idempotency_key="dlq",
        ).get(propagate=True)

    assert sent_payload["queue"] == settings.CELERY_DEAD_LETTER_QUEUE
    assert sent_payload["name"] == "tasks.dead_letter.handle_dead_letter"
    assert json.loads(sent_payload["args"][0])["task"] == "tests.unstable_task"
