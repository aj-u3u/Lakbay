"""add expenses shared costing tables

Revision ID: 0008_expenses_shared_costing
Revises: 0007_group_collaboration
Create Date: 2026-09-19 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0008_expenses_shared_costing"
down_revision: str | Sequence[str] | None = "0007_group_collaboration"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trip_expenses",
        sa.Column("trip_expense_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("paid_by_trip_member_id", sa.Integer(), nullable=False),
        sa.Column("created_by_user_id", sa.Integer(), nullable=False),
        sa.Column("category", sa.String(length=50), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("amount", sa.Numeric(10, 2), nullable=False),
        sa.Column("expense_date", sa.Date(), nullable=False),
        sa.Column(
            "split_method",
            sa.String(length=50),
            server_default=sa.text("'equal'"),
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.String(length=50),
            server_default=sa.text("'active'"),
            nullable=False,
        ),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "category IN ('transportation', 'accommodation', 'meals', 'activities', 'other')",
            name="ck_trip_expenses_category",
        ),
        sa.CheckConstraint(
            "status IN ('active', 'voided')",
            name="ck_trip_expenses_status",
        ),
        sa.CheckConstraint(
            "split_method IN ('equal')",
            name="ck_trip_expenses_split_method",
        ),
        sa.CheckConstraint(
            "amount > 0",
            name="ck_trip_expenses_amount_positive",
        ),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["users.user_id"],
            name="fk_trip_expenses_created_by_user_id_users",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["paid_by_trip_member_id"],
            ["trip_members.trip_member_id"],
            name="fk_trip_expenses_paid_by_trip_member_id_trip_members",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.trip_id"],
            name="fk_trip_expenses_trip_id_trips",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("trip_expense_id", name="pk_trip_expenses"),
    )
    op.create_index(
        op.f("ix_trip_expenses_category"),
        "trip_expenses",
        ["category"],
    )
    op.create_index(
        op.f("ix_trip_expenses_created_by_user_id"),
        "trip_expenses",
        ["created_by_user_id"],
    )
    op.create_index(
        op.f("ix_trip_expenses_expense_date"),
        "trip_expenses",
        ["expense_date"],
    )
    op.create_index(
        op.f("ix_trip_expenses_paid_by_trip_member_id"),
        "trip_expenses",
        ["paid_by_trip_member_id"],
    )
    op.create_index(
        op.f("ix_trip_expenses_status"),
        "trip_expenses",
        ["status"],
    )
    op.create_index(
        op.f("ix_trip_expenses_trip_expense_id"),
        "trip_expenses",
        ["trip_expense_id"],
    )
    op.create_index(
        op.f("ix_trip_expenses_trip_id"),
        "trip_expenses",
        ["trip_id"],
    )

    op.create_table(
        "trip_expense_splits",
        sa.Column(
            "trip_expense_split_id",
            sa.Integer(),
            autoincrement=True,
            nullable=False,
        ),
        sa.Column("trip_expense_id", sa.Integer(), nullable=False),
        sa.Column("trip_member_id", sa.Integer(), nullable=False),
        sa.Column("share_amount", sa.Numeric(10, 2), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "share_amount >= 0",
            name="ck_trip_expense_splits_share_amount_non_negative",
        ),
        sa.ForeignKeyConstraint(
            ["trip_expense_id"],
            ["trip_expenses.trip_expense_id"],
            name="fk_trip_expense_splits_trip_expense_id_trip_expenses",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["trip_member_id"],
            ["trip_members.trip_member_id"],
            name="fk_trip_expense_splits_trip_member_id_trip_members",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint(
            "trip_expense_split_id",
            name="pk_trip_expense_splits",
        ),
        sa.UniqueConstraint(
            "trip_expense_id",
            "trip_member_id",
            name="uq_trip_expense_splits_expense_id_member_id",
        ),
    )
    op.create_index(
        op.f("ix_trip_expense_splits_trip_expense_id"),
        "trip_expense_splits",
        ["trip_expense_id"],
    )
    op.create_index(
        op.f("ix_trip_expense_splits_trip_expense_split_id"),
        "trip_expense_splits",
        ["trip_expense_split_id"],
    )
    op.create_index(
        op.f("ix_trip_expense_splits_trip_member_id"),
        "trip_expense_splits",
        ["trip_member_id"],
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_trip_expense_splits_trip_member_id"),
        table_name="trip_expense_splits",
    )
    op.drop_index(
        op.f("ix_trip_expense_splits_trip_expense_split_id"),
        table_name="trip_expense_splits",
    )
    op.drop_index(
        op.f("ix_trip_expense_splits_trip_expense_id"),
        table_name="trip_expense_splits",
    )
    op.drop_table("trip_expense_splits")

    op.drop_index(op.f("ix_trip_expenses_trip_id"), table_name="trip_expenses")
    op.drop_index(
        op.f("ix_trip_expenses_trip_expense_id"),
        table_name="trip_expenses",
    )
    op.drop_index(op.f("ix_trip_expenses_status"), table_name="trip_expenses")
    op.drop_index(
        op.f("ix_trip_expenses_paid_by_trip_member_id"),
        table_name="trip_expenses",
    )
    op.drop_index(
        op.f("ix_trip_expenses_expense_date"),
        table_name="trip_expenses",
    )
    op.drop_index(
        op.f("ix_trip_expenses_created_by_user_id"),
        table_name="trip_expenses",
    )
    op.drop_index(op.f("ix_trip_expenses_category"), table_name="trip_expenses")
    op.drop_table("trip_expenses")
