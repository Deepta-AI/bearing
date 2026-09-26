"""The migration pipeline produced the schema the models describe."""

import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import SchemaProbe

pytestmark = pytest.mark.integration


async def test_probe_table_exists_and_is_empty(session: AsyncSession) -> None:
    count = await session.scalar(select(func.count()).select_from(SchemaProbe))

    assert count == 0


async def test_insert_is_rolled_back_between_tests(session: AsyncSession) -> None:
    session.add(SchemaProbe())
    await session.flush()

    count = await session.scalar(select(func.count()).select_from(SchemaProbe))

    assert count == 1
