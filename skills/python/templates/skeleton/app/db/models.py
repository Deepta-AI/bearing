"""SQLAlchemy models. Every module with models must be imported by alembic/env.py."""

from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin


class SchemaProbe(TimestampMixin, Base):
    """Proves the migration pipeline works. Delete it with the first real model."""

    __tablename__ = "schema_probe"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
