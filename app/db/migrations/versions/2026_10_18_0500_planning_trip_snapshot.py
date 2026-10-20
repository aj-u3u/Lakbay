"""Persist the selected planning preview with a saved trip.

Revision ID: 2026_10_18_0500
Revises: dfc235ae4bed
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "2026_10_18_0500"
down_revision: str | Sequence[str] | None = "dfc235ae4bed"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("trips", sa.Column("planning_snapshot", sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column("trips", "planning_snapshot")
