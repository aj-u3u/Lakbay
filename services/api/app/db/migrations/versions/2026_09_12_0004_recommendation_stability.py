"""stabilize recommendation interactions

Revision ID: 0004_recommendation_stability
Revises: 0003_recommendation_signals
Create Date: 2026-09-12 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0004_recommendation_stability"
down_revision: str | Sequence[str] | None = "0003_recommendation_signals"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index(
        "uq_destination_interactions_user_destination_non_view_type",
        "destination_interactions",
        ["user_id", "destination_id", "interaction_type"],
        unique=True,
        postgresql_where=sa.text("interaction_type != 'view'"),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_destination_interactions_user_destination_non_view_type",
        table_name="destination_interactions",
    )
