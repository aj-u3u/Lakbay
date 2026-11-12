"""add trip memories

Revision ID: 0010_trip_memories
Revises: 0009_expense_integrity
Create Date: 2026-09-21 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0010_trip_memories"
down_revision: str | Sequence[str] | None = "0009_expense_integrity"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trip_memories",
        sa.Column("trip_memory_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("uploaded_by_user_id", sa.Integer(), nullable=False),
        sa.Column("uploaded_by_trip_member_id", sa.Integer(), nullable=False),
        sa.Column("destination_id", sa.Integer(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=False),
        sa.Column("cloudinary_public_id", sa.String(length=500), nullable=True),
        sa.Column("caption", sa.Text(), nullable=True),
        sa.Column("location_tag", sa.String(length=255), nullable=True),
        sa.Column("taken_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "status",
            sa.String(length=50),
            server_default=sa.text("'active'"),
            nullable=False,
        ),
        sa.Column(
            "like_count",
            sa.Integer(),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column(
            "comment_count",
            sa.Integer(),
            server_default=sa.text("0"),
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
            "status IN ('active', 'deleted')",
            name="ck_trip_memories_status",
        ),
        sa.CheckConstraint(
            "like_count >= 0",
            name="ck_trip_memories_like_count_non_negative",
        ),
        sa.CheckConstraint(
            "comment_count >= 0",
            name="ck_trip_memories_comment_count_non_negative",
        ),
        sa.ForeignKeyConstraint(
            ["destination_id"],
            ["destinations.destination_id"],
            name="fk_trip_memories_destination_id_destinations",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.trip_id"],
            name="fk_trip_memories_trip_id_trips",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id", "uploaded_by_trip_member_id"],
            ["trip_members.trip_id", "trip_members.trip_member_id"],
            name="fk_trip_memories_uploader_same_trip",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["uploaded_by_user_id"],
            ["users.user_id"],
            name="fk_trip_memories_uploaded_by_user_id_users",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("trip_memory_id", name="pk_trip_memories"),
    )
    op.create_index(
        op.f("ix_trip_memories_cloudinary_public_id"),
        "trip_memories",
        ["cloudinary_public_id"],
    )
    op.create_index(
        op.f("ix_trip_memories_destination_id"),
        "trip_memories",
        ["destination_id"],
    )
    op.create_index(
        op.f("ix_trip_memories_status"),
        "trip_memories",
        ["status"],
    )
    op.create_index(
        op.f("ix_trip_memories_trip_id"),
        "trip_memories",
        ["trip_id"],
    )
    op.create_index(
        op.f("ix_trip_memories_trip_memory_id"),
        "trip_memories",
        ["trip_memory_id"],
    )
    op.create_index(
        op.f("ix_trip_memories_uploaded_by_trip_member_id"),
        "trip_memories",
        ["uploaded_by_trip_member_id"],
    )
    op.create_index(
        op.f("ix_trip_memories_uploaded_by_user_id"),
        "trip_memories",
        ["uploaded_by_user_id"],
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_trip_memories_uploaded_by_user_id"),
        table_name="trip_memories",
    )
    op.drop_index(
        op.f("ix_trip_memories_uploaded_by_trip_member_id"),
        table_name="trip_memories",
    )
    op.drop_index(op.f("ix_trip_memories_trip_memory_id"), table_name="trip_memories")
    op.drop_index(op.f("ix_trip_memories_trip_id"), table_name="trip_memories")
    op.drop_index(op.f("ix_trip_memories_status"), table_name="trip_memories")
    op.drop_index(op.f("ix_trip_memories_destination_id"), table_name="trip_memories")
    op.drop_index(
        op.f("ix_trip_memories_cloudinary_public_id"),
        table_name="trip_memories",
    )
    op.drop_table("trip_memories")
