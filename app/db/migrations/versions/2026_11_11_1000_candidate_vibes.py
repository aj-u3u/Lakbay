"""Add vibes to destination candidates so publishing can carry them over.

Revision ID: 2026_11_11_1000
Revises: 2026_11_09_0900

Additive and nullable: existing rows keep NULL and nothing is rewritten.
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "2026_11_11_1000"
down_revision: str | Sequence[str] | None = "2026_11_09_0900"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "destination_candidates",
        sa.Column("vibes", sa.String(500), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("destination_candidates", "vibes")
