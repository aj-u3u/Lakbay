"""allow unknown destination estimated cost

Revision ID: 95bb71db451f
Revises: 2026_10_29_0600
Create Date: 2026-11-01 02:37:24.391813+00:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa



revision: str = '95bb71db451f'
down_revision: str | Sequence[str] | None = '2026_10_29_0600'
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.alter_column(
        "destinations", "estimated_cost",
        existing_type=sa.Numeric(precision=10, scale=2),
        existing_nullable=False,
        nullable=True,
    )


def downgrade() -> None:
    # Restore known costs before downgrading; PostgreSQL rejects NULL rows here.
    op.alter_column(
        "destinations", "estimated_cost",
        existing_type=sa.Numeric(precision=10, scale=2),
        existing_nullable=True,
        nullable=False,
    )
