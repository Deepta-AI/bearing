"""Shared fixtures: settings that ignore .env, the app, and an HTTP client.

No database is needed. The engine is created but never connects; routes that
touch it are exercised through dependency overrides.
"""

from collections.abc import AsyncIterator

import pytest
from asgi_lifespan import LifespanManager
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.core.config import Settings
from app.main import create_app


@pytest.fixture
def settings() -> Settings:
    """Test settings, independent of any .env file on the machine."""
    return Settings(
        _env_file=None,
        env="test",
        log_format="console",
        database_url="postgresql+asyncpg://postgres:postgres@localhost:5432/test",
    )


@pytest.fixture
async def app(settings: Settings) -> AsyncIterator[FastAPI]:
    """The application with its lifespan run, so `app.state` is populated."""
    application = create_app(settings)
    async with LifespanManager(application):
        yield application


@pytest.fixture
async def client(app: FastAPI) -> AsyncIterator[AsyncClient]:
    """An HTTP client talking to the app in-process."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client
