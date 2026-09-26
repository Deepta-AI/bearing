"""Liveness and readiness. Readiness checks every dependency the service needs."""

from collections.abc import Awaitable, Callable
from functools import partial
from typing import Annotated

import structlog
from fastapi import APIRouter, Depends, Request
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncEngine

from app.api.health.schemas import HealthOut, ReadyOut
from app.core.errors import ErrorEnvelope, ServiceUnavailableError
from app.db.session import ping_database

log = structlog.get_logger()
router = APIRouter(tags=["health"])

ReadinessCheck = Callable[[], Awaitable[None]]


def get_version(request: Request) -> str:
    """The application version, as a dependency so tests can pin it."""
    version: str = request.app.version
    return version


def get_readiness_check(request: Request) -> ReadinessCheck:
    """The database ping bound to the engine the lifespan created."""
    engine: AsyncEngine = request.app.state.engine
    return partial(ping_database, engine)


@router.get("/healthz", response_model=HealthOut)
async def healthz(version: Annotated[str, Depends(get_version)]) -> HealthOut:
    """The process is up and serving."""
    return HealthOut(status="ok", version=version)


@router.get("/readyz", response_model=ReadyOut, responses={503: {"model": ErrorEnvelope}})
async def readyz(check: Annotated[ReadinessCheck, Depends(get_readiness_check)]) -> ReadyOut:
    """Every dependency is reachable; 503 with the failed check otherwise."""
    try:
        await check()
    except (OSError, TimeoutError, SQLAlchemyError) as exc:
        log.warning("readiness failed", check="database", error_type=type(exc).__name__)
        raise ServiceUnavailableError(
            "database unreachable", details={"database": "failed"}
        ) from exc
    return ReadyOut(status="ok", checks={"database": "ok"})
