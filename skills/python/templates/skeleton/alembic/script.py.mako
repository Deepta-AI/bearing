"""${message}

Revision: ${up_revision}
Revises: ${down_revision | comma,n}
Created: ${create_date}

Index decision: <state which filters this serves, or "none">.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
${imports if imports else ""}

revision: str = ${repr(up_revision)}
down_revision: str | None = ${repr(down_revision)}
branch_labels: str | Sequence[str] | None = ${repr(branch_labels)}
depends_on: str | Sequence[str] | None = ${repr(depends_on)}


def upgrade() -> None:
    """Apply this migration."""
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    """Undo this migration. It must work; `make migrate-down` proves it."""
    ${downgrades if downgrades else "pass"}
