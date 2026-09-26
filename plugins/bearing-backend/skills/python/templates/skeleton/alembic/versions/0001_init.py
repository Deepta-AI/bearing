"""init

Revision: 0001
Revises: None
Created: 2026-01-01

Index decision: none yet; this migration only proves the pipeline.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create the probe table."""
    op.create_table(
        "schema_probe",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_schema_probe")),
    )


def downgrade() -> None:
    """Drop the probe table."""
    op.drop_table("schema_probe")
