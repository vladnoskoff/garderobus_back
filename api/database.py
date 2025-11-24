from __future__ import annotations

import random
from contextlib import contextmanager
from typing import Iterator, List

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.engine.url import make_url
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.sql import Select
from prometheus_client import Gauge

import settings


_db_pool_size = Gauge(
    "app_db_pool_size",
    "Configured SQLAlchemy pool size.",
    labelnames=("role",),
)
_db_pool_in_use = Gauge(
    "app_db_pool_in_use",
    "Connections currently checked out from the pool.",
    labelnames=("role",),
)
_db_pool_overflow = Gauge(
    "app_db_pool_overflow",
    "Overflow connections created beyond the base pool size.",
    labelnames=("role",),
)


def _build_engine(url: str) -> Engine:
    """Create a SQLAlchemy engine with pooling tuned for Postgres."""

    engine_kwargs: dict = {"pool_pre_ping": settings.DATABASE_POOL_PRE_PING}
    backend = make_url(url).get_backend_name()

    if backend != "sqlite":
        engine_kwargs.update(
            pool_size=settings.DATABASE_POOL_SIZE,
            max_overflow=settings.DATABASE_MAX_OVERFLOW,
            pool_timeout=settings.DATABASE_POOL_TIMEOUT,
            pool_recycle=settings.DATABASE_POOL_RECYCLE,
        )
    else:
        # SQLite in tests uses a special pool that ignores pooling options.
        engine_kwargs.setdefault("connect_args", {"check_same_thread": False})

    return create_engine(url, **engine_kwargs)


def _safe_pool_metric(engine: Engine, attribute: str) -> float:
    try:
        pool = engine.pool
        value = getattr(pool, attribute, None)
        if callable(value):
            return float(value() or 0)
        return float(value or 0)
    except Exception:
        return 0.0


def _instrument_pool(engine: Engine, role: str) -> None:
    """Expose connection pool metrics to Prometheus."""

    _db_pool_size.labels(role).set_function(
        lambda eng=engine: _safe_pool_metric(eng, "size")
    )
    _db_pool_in_use.labels(role).set_function(
        lambda eng=engine: _safe_pool_metric(eng, "checkedout")
    )
    _db_pool_overflow.labels(role).set_function(
        lambda eng=engine: _safe_pool_metric(eng, "overflow")
    )


WRITE_ENGINE: Engine = _build_engine(settings.DATABASE_URL)
_instrument_pool(WRITE_ENGINE, "write")
READ_ENGINES: List[Engine] = []

if settings.DATABASE_USE_REPLICAS:
    for idx, replica_url in enumerate(settings.DATABASE_READ_REPLICAS):
        engine = _build_engine(replica_url)
        READ_ENGINES.append(engine)
        _instrument_pool(engine, f"read:{idx}")


class RoutingSession(Session):
    """Route read-only operations to replicas when available."""

    def get_bind(self, mapper=None, clause=None, **kwargs):  # type: ignore[override]
        if self.info.get("force_write") or self._flushing:
            return WRITE_ENGINE

        if not settings.DATABASE_USE_REPLICAS or not READ_ENGINES:
            return WRITE_ENGINE

        if clause is not None:
            is_select = isinstance(clause, Select) or getattr(clause, "__visit_name__", "") == "select"
            if not is_select:
                return WRITE_ENGINE

        if self.info.get("use_replica"):
            return random.choice(READ_ENGINES)

        return WRITE_ENGINE


SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    class_=RoutingSession,
    bind=WRITE_ENGINE,
)

Base = declarative_base()

# Backwards compatibility for modules importing ``engine`` directly.
# Older code expected ``database.engine`` to reference the primary write
# engine.  Expose an alias so existing imports keep working.
engine = WRITE_ENGINE


@contextmanager
def db_session(*, read_only: bool = False) -> Iterator[Session]:
    session: RoutingSession = SessionLocal()  # type: ignore[assignment]
    if read_only:
        session.info["use_replica"] = True
    try:
        yield session
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def get_db(read_only: bool = False) -> Iterator[Session]:
    with db_session(read_only=read_only) as session:
        yield session


def get_read_db() -> Iterator[Session]:
    yield from get_db(read_only=True)
