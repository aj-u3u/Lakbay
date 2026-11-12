"""add trip reviews

Revision ID: 0011_trip_reviews
Revises: 0010_trip_memories
Create Date: 2026-09-22 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0011_trip_reviews"
down_revision: str | Sequence[str] | None = "0010_trip_memories"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trip_reviews",
        sa.Column("trip_review_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("trip_member_id", sa.Integer(), nullable=False),
        sa.Column("destination_id", sa.Integer(), nullable=True),
        sa.Column("post_trip_rating", sa.Integer(), nullable=False),
        sa.Column("accuracy_rating", sa.Integer(), nullable=False),
        sa.Column("route_efficiency_rating", sa.Integer(), nullable=False),
        sa.Column("budget_adherence_rating", sa.Integer(), nullable=False),
        sa.Column("overall_experience_rating", sa.Integer(), nullable=False),
        sa.Column("comments", sa.Text(), nullable=True),
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
            "post_trip_rating BETWEEN 1 AND 5",
            name="ck_trip_reviews_post_trip_rating_range",
        ),
        sa.CheckConstraint(
            "accuracy_rating BETWEEN 1 AND 5",
            name="ck_trip_reviews_accuracy_rating_range",
        ),
        sa.CheckConstraint(
            "route_efficiency_rating BETWEEN 1 AND 5",
            name="ck_trip_reviews_route_efficiency_rating_range",
        ),
        sa.CheckConstraint(
            "budget_adherence_rating BETWEEN 1 AND 5",
            name="ck_trip_reviews_budget_adherence_rating_range",
        ),
        sa.CheckConstraint(
            "overall_experience_rating BETWEEN 1 AND 5",
            name="ck_trip_reviews_overall_experience_rating_range",
        ),
        sa.CheckConstraint(
            "status IN ('active', 'deleted')",
            name="ck_trip_reviews_status",
        ),
        sa.ForeignKeyConstraint(
            ["destination_id"],
            ["destinations.destination_id"],
            name="fk_trip_reviews_destination_id_destinations",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.trip_id"],
            name="fk_trip_reviews_trip_id_trips",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id", "trip_member_id"],
            ["trip_members.trip_id", "trip_members.trip_member_id"],
            name="fk_trip_reviews_member_same_trip",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.user_id"],
            name="fk_trip_reviews_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("trip_review_id", name="pk_trip_reviews"),
    )
    op.create_index(
        op.f("ix_trip_reviews_destination_id"),
        "trip_reviews",
        ["destination_id"],
    )
    op.create_index(op.f("ix_trip_reviews_status"), "trip_reviews", ["status"])
    op.create_index(op.f("ix_trip_reviews_trip_id"), "trip_reviews", ["trip_id"])
    op.create_index(
        op.f("ix_trip_reviews_trip_member_id"),
        "trip_reviews",
        ["trip_member_id"],
    )
    op.create_index(
        op.f("ix_trip_reviews_trip_review_id"),
        "trip_reviews",
        ["trip_review_id"],
    )
    op.create_index(op.f("ix_trip_reviews_user_id"), "trip_reviews", ["user_id"])
    op.create_index(
        "uq_trip_reviews_active_trip_user",
        "trip_reviews",
        ["trip_id", "user_id"],
        unique=True,
        postgresql_where=sa.text("destination_id IS NULL AND status = 'active'"),
        sqlite_where=sa.text("destination_id IS NULL AND status = 'active'"),
    )
    op.create_index(
        "uq_trip_reviews_active_destination_user",
        "trip_reviews",
        ["trip_id", "user_id", "destination_id"],
        unique=True,
        postgresql_where=sa.text("destination_id IS NOT NULL AND status = 'active'"),
        sqlite_where=sa.text("destination_id IS NOT NULL AND status = 'active'"),
    )


def downgrade() -> None:
    op.drop_index("uq_trip_reviews_active_destination_user", table_name="trip_reviews")
    op.drop_index("uq_trip_reviews_active_trip_user", table_name="trip_reviews")
    op.drop_index(op.f("ix_trip_reviews_user_id"), table_name="trip_reviews")
    op.drop_index(op.f("ix_trip_reviews_trip_review_id"), table_name="trip_reviews")
    op.drop_index(op.f("ix_trip_reviews_trip_member_id"), table_name="trip_reviews")
    op.drop_index(op.f("ix_trip_reviews_trip_id"), table_name="trip_reviews")
    op.drop_index(op.f("ix_trip_reviews_status"), table_name="trip_reviews")
    op.drop_index(op.f("ix_trip_reviews_destination_id"), table_name="trip_reviews")
    op.drop_table("trip_reviews")
