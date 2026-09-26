"""Integration fixtures: a real engine on DATABASE_URL, each test rolled back."""

import os
from collections.abc import AsyncIterator

import pytest
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, create_async_engine


@pytest.fixture
async def engine() -> AsyncIterator[AsyncEngine]:
    """The migrated database named by DATABASE_URL. Fails loudly when unset."""
    url = os.environ.get("DATABASE_URL")
    if not url:
        pytest.fail("DATABASE_URL is not set; run make db, make migrate, make test-integration")
    engine = create_async_engine(url)
    try:
        yield engine
    finally:
        await engine.dispose()


@pytest.fixture
async def session(engine: AsyncEngine) -> AsyncIterator[AsyncSession]:
    """A session inside a transaction that is always rolled back."""
    async with engine.connect() as connection:
        transaction = await connection.begin()
        try:
            yield AsyncSession(bind=connection, expire_on_commit=False)
        finally:
            await transaction.rollback()
