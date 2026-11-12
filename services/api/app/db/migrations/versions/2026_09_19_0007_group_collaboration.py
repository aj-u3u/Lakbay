"""add group collaboration tables

Revision ID: 0007_group_collaboration
Revises: 0006_trip_management
Create Date: 2026-09-19 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0007_group_collaboration"
down_revision: str | Sequence[str] | None = "0006_trip_management"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trip_members",
        sa.Column("trip_member_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("role", sa.String(length=50), nullable=False),
        sa.Column("status", sa.String(length=50), nullable=False),
        sa.Column(
            "joined_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
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
            "role IN ('owner', 'organizer', 'member')",
            name="ck_trip_members_role",
        ),
        sa.CheckConstraint(
            "status IN ('active', 'removed')",
            name="ck_trip_members_status",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.trip_id"],
            name="fk_trip_members_trip_id_trips",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.user_id"],
            name="fk_trip_members_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("trip_member_id", name="pk_trip_members"),
        sa.UniqueConstraint(
            "trip_id",
            "user_id",
            name="uq_trip_members_trip_id_user_id",
        ),
    )
    op.create_index(
        op.f("ix_trip_members_status"),
        "trip_members",
        ["status"],
    )
    op.create_index(
        op.f("ix_trip_members_trip_id"),
        "trip_members",
        ["trip_id"],
    )
    op.create_index(
        op.f("ix_trip_members_trip_member_id"),
        "trip_members",
        ["trip_member_id"],
    )
    op.create_index(
        op.f("ix_trip_members_user_id"),
        "trip_members",
        ["user_id"],
    )

    op.execute(
        """
        INSERT INTO trip_members (trip_id, user_id, role, status)
        SELECT trip_id, owner_user_id, 'owner', 'active'
        FROM trips
        """
    )

    op.create_table(
        "trip_tasks",
        sa.Column("trip_task_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("created_by_user_id", sa.Integer(), nullable=False),
        sa.Column("assigned_trip_member_id", sa.Integer(), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=50), nullable=False),
        sa.Column("due_date", sa.Date(), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
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
            "status IN ('pending', 'ongoing', 'completed')",
            name="ck_trip_tasks_status",
        ),
        sa.ForeignKeyConstraint(
            ["assigned_trip_member_id"],
            ["trip_members.trip_member_id"],
            name="fk_trip_tasks_assigned_member",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["users.user_id"],
            name="fk_trip_tasks_created_by_user",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.trip_id"],
            name="fk_trip_tasks_trip_id_trips",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("trip_task_id", name="pk_trip_tasks"),
    )
    op.create_index(
        op.f("ix_trip_tasks_assigned_trip_member_id"),
        "trip_tasks",
        ["assigned_trip_member_id"],
    )
    op.create_index(
        op.f("ix_trip_tasks_created_by_user_id"),
        "trip_tasks",
        ["created_by_user_id"],
    )
    op.create_index(
        op.f("ix_trip_tasks_status"),
        "trip_tasks",
        ["status"],
    )
    op.create_index(
        op.f("ix_trip_tasks_trip_id"),
        "trip_tasks",
        ["trip_id"],
    )
    op.create_index(
        op.f("ix_trip_tasks_trip_task_id"),
        "trip_tasks",
        ["trip_task_id"],
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_trip_tasks_trip_task_id"), table_name="trip_tasks")
    op.drop_index(op.f("ix_trip_tasks_trip_id"), table_name="trip_tasks")
    op.drop_index(op.f("ix_trip_tasks_status"), table_name="trip_tasks")
    op.drop_index(op.f("ix_trip_tasks_created_by_user_id"), table_name="trip_tasks")
    op.drop_index(
        op.f("ix_trip_tasks_assigned_trip_member_id"),
        table_name="trip_tasks",
    )
    op.drop_table("trip_tasks")

    op.drop_index(op.f("ix_trip_members_user_id"), table_name="trip_members")
    op.drop_index(op.f("ix_trip_members_trip_member_id"), table_name="trip_members")
    op.drop_index(op.f("ix_trip_members_trip_id"), table_name="trip_members")
    op.drop_index(op.f("ix_trip_members_status"), table_name="trip_members")
    op.drop_table("trip_members")
