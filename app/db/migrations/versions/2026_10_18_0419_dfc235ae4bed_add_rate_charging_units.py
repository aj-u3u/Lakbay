"""Add currency and charging units to catalog rates.

Revision ID: dfc235ae4bed
Revises: 0013_notifications
Create Date: 2026-10-18 04:19:18.884180+00:00
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "dfc235ae4bed"
down_revision: str | Sequence[str] | None = "0013_notifications"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Existing rows keep their IDs. Their old prices have an unverified unit.
    op.add_column(
        "accommodations",
        sa.Column("currency", sa.String(length=3), server_default="PHP", nullable=False),
    )
    op.add_column(
        "accommodations",
        sa.Column("charging_unit", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "transportations",
        sa.Column("currency", sa.String(length=3), server_default="PHP", nullable=False),
    )
    op.add_column(
        "transportations",
        sa.Column("charging_unit", sa.String(length=32), nullable=True),
    )
    op.create_check_constraint(
        "ck_accommodations_currency_php", "accommodations", "currency = 'PHP'"
    )
    op.create_check_constraint(
        "ck_accommodations_charging_unit",
        "accommodations",
        "charging_unit IS NULL OR charging_unit IN "
        "('per_room_per_night', 'per_room_per_stay')",
    )
    op.create_check_constraint(
        "ck_transportations_currency_php", "transportations", "currency = 'PHP'"
    )
    op.create_check_constraint(
        "ck_transportations_charging_unit",
        "transportations",
        "charging_unit IS NULL OR charging_unit IN "
        "('per_person', 'per_vehicle', 'per_group')",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_transportations_charging_unit", "transportations", type_="check"
    )
    op.drop_constraint(
        "ck_transportations_currency_php", "transportations", type_="check"
    )
    op.drop_constraint(
        "ck_accommodations_charging_unit", "accommodations", type_="check"
    )
    op.drop_constraint(
        "ck_accommodations_currency_php", "accommodations", type_="check"
    )
    op.drop_column("transportations", "charging_unit")
    op.drop_column("transportations", "currency")
    op.drop_column("accommodations", "charging_unit")
    op.drop_column("accommodations", "currency")
