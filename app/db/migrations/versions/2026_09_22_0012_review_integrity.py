"""stabilize trip review same-trip integrity

Revision ID: 0012_review_integrity
Revises: 0011_trip_reviews
Create Date: 2026-09-22 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op


revision: str = "0012_review_integrity"
down_revision: str | Sequence[str] | None = "0011_trip_reviews"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_foreign_key(
        "fk_trip_reviews_user_same_trip",
        "trip_reviews",
        "trip_members",
        ["trip_id", "user_id"],
        ["trip_id", "user_id"],
        ondelete="RESTRICT",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_trip_reviews_user_same_trip",
        "trip_reviews",
        type_="foreignkey",
    )
