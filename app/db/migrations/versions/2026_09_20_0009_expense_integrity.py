"""stabilize expense same-trip integrity

Revision ID: 0009_expense_integrity
Revises: 0008_expenses_shared_costing
Create Date: 2026-09-20 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0009_expense_integrity"
down_revision: str | Sequence[str] | None = "0008_expenses_shared_costing"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "trip_expense_splits",
        sa.Column("trip_id", sa.Integer(), nullable=True),
    )
    op.execute(
        """
        UPDATE trip_expense_splits
        SET trip_id = trip_expenses.trip_id
        FROM trip_expenses
        WHERE trip_expense_splits.trip_expense_id = trip_expenses.trip_expense_id
        """
    )
    op.alter_column("trip_expense_splits", "trip_id", nullable=False)
    op.create_index(
        op.f("ix_trip_expense_splits_trip_id"),
        "trip_expense_splits",
        ["trip_id"],
    )
    op.create_unique_constraint(
        "uq_trip_members_trip_id_trip_member_id",
        "trip_members",
        ["trip_id", "trip_member_id"],
    )
    op.create_unique_constraint(
        "uq_trip_expenses_trip_id_trip_expense_id",
        "trip_expenses",
        ["trip_id", "trip_expense_id"],
    )
    op.create_foreign_key(
        "fk_trip_expenses_trip_member_same_trip",
        "trip_expenses",
        "trip_members",
        ["trip_id", "paid_by_trip_member_id"],
        ["trip_id", "trip_member_id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "fk_trip_expense_splits_expense_same_trip",
        "trip_expense_splits",
        "trip_expenses",
        ["trip_id", "trip_expense_id"],
        ["trip_id", "trip_expense_id"],
        ondelete="CASCADE",
    )
    op.create_foreign_key(
        "fk_trip_expense_splits_member_same_trip",
        "trip_expense_splits",
        "trip_members",
        ["trip_id", "trip_member_id"],
        ["trip_id", "trip_member_id"],
        ondelete="RESTRICT",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_trip_expense_splits_member_same_trip",
        "trip_expense_splits",
        type_="foreignkey",
    )
    op.drop_constraint(
        "fk_trip_expense_splits_expense_same_trip",
        "trip_expense_splits",
        type_="foreignkey",
    )
    op.drop_constraint(
        "fk_trip_expenses_trip_member_same_trip",
        "trip_expenses",
        type_="foreignkey",
    )
    op.drop_constraint(
        "uq_trip_expenses_trip_id_trip_expense_id",
        "trip_expenses",
        type_="unique",
    )
    op.drop_constraint(
        "uq_trip_members_trip_id_trip_member_id",
        "trip_members",
        type_="unique",
    )
    op.drop_index(op.f("ix_trip_expense_splits_trip_id"), table_name="trip_expense_splits")
    op.drop_column("trip_expense_splits", "trip_id")
