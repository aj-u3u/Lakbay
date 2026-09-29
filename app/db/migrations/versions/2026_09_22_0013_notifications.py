"""add notifications

Revision ID: 0013_notifications
Revises: 0012_review_integrity
Create Date: 2026-09-22 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0013_notifications"
down_revision: str | Sequence[str] | None = "0012_review_integrity"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "notifications",
        sa.Column("notification_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("recipient_user_id", sa.Integer(), nullable=False),
        sa.Column("actor_user_id", sa.Integer(), nullable=True),
        sa.Column("trip_id", sa.Integer(), nullable=True),
        sa.Column("event_type", sa.String(length=100), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("entity_type", sa.String(length=100), nullable=True),
        sa.Column("entity_id", sa.Integer(), nullable=True),
        sa.Column(
            "metadata",
            sa.JSON(),
            server_default=sa.text("'{}'"),
            nullable=False,
        ),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "status",
            sa.String(length=50),
            server_default=sa.text("'active'"),
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
            (
                "event_type IN ("
                "'trip_member_added', "
                "'task_assigned', "
                "'task_updated', "
                "'expense_created', "
                "'expense_updated', "
                "'expense_voided', "
                "'trip_updated', "
                "'trip_route_updated'"
                ")"
            ),
            name="ck_notifications_event_type",
        ),
        sa.CheckConstraint(
            (
                "entity_type IS NULL OR entity_type IN ("
                "'trip', "
                "'trip_member', "
                "'trip_task', "
                "'trip_expense', "
                "'trip_route'"
                ")"
            ),
            name="ck_notifications_entity_type",
        ),
        sa.CheckConstraint(
            "status IN ('active', 'deleted')",
            name="ck_notifications_status",
        ),
        sa.CheckConstraint(
            (
                "(entity_type IS NULL AND entity_id IS NULL) OR "
                "(entity_type IS NOT NULL AND entity_id IS NOT NULL)"
            ),
            name="ck_notifications_entity_pair",
        ),
        sa.ForeignKeyConstraint(
            ["actor_user_id"],
            ["users.user_id"],
            name="fk_notifications_actor_user_id_users",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["recipient_user_id"],
            ["users.user_id"],
            name="fk_notifications_recipient_user_id_users",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.trip_id"],
            name="fk_notifications_trip_id_trips",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("notification_id", name="pk_notifications"),
    )
    op.create_index(
        op.f("ix_notifications_actor_user_id"),
        "notifications",
        ["actor_user_id"],
    )
    op.create_index(
        op.f("ix_notifications_created_at"),
        "notifications",
        ["created_at"],
    )
    op.create_index(
        op.f("ix_notifications_entity_id"),
        "notifications",
        ["entity_id"],
    )
    op.create_index(
        op.f("ix_notifications_entity_type"),
        "notifications",
        ["entity_type"],
    )
    op.create_index(
        op.f("ix_notifications_event_type"),
        "notifications",
        ["event_type"],
    )
    op.create_index(
        op.f("ix_notifications_notification_id"),
        "notifications",
        ["notification_id"],
    )
    op.create_index(
        op.f("ix_notifications_read_at"),
        "notifications",
        ["read_at"],
    )
    op.create_index(
        op.f("ix_notifications_recipient_user_id"),
        "notifications",
        ["recipient_user_id"],
    )
    op.create_index(
        "ix_notifications_recipient_status_created",
        "notifications",
        ["recipient_user_id", "status", "created_at"],
    )
    op.create_index(op.f("ix_notifications_status"), "notifications", ["status"])
    op.create_index(op.f("ix_notifications_trip_id"), "notifications", ["trip_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_notifications_trip_id"), table_name="notifications")
    op.drop_index(op.f("ix_notifications_status"), table_name="notifications")
    op.drop_index("ix_notifications_recipient_status_created", table_name="notifications")
    op.drop_index(op.f("ix_notifications_recipient_user_id"), table_name="notifications")
    op.drop_index(op.f("ix_notifications_read_at"), table_name="notifications")
    op.drop_index(op.f("ix_notifications_notification_id"), table_name="notifications")
    op.drop_index(op.f("ix_notifications_event_type"), table_name="notifications")
    op.drop_index(op.f("ix_notifications_entity_type"), table_name="notifications")
    op.drop_index(op.f("ix_notifications_entity_id"), table_name="notifications")
    op.drop_index(op.f("ix_notifications_created_at"), table_name="notifications")
    op.drop_index(op.f("ix_notifications_actor_user_id"), table_name="notifications")
    op.drop_table("notifications")
