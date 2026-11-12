"""recommendation signals

Revision ID: 0003_recommendation_signals
Revises: 0002_destination_data_foundation
Create Date: 2026-09-12 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0003_recommendation_signals"
down_revision: str | Sequence[str] | None = "0002_destination_data_foundation"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "user_preference_signals",
        sa.Column(
            "preference_signal_id",
            sa.Integer(),
            autoincrement=True,
            nullable=False,
        ),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("preferred_categories", sa.JSON(), nullable=False),
        sa.Column("preferred_vibes", sa.JSON(), nullable=False),
        sa.Column("preferred_activities", sa.JSON(), nullable=False),
        sa.Column("preferred_districts", sa.JSON(), nullable=False),
        sa.Column("budget_class", sa.String(length=50), nullable=True),
        sa.Column("difficulty_level", sa.String(length=50), nullable=True),
        sa.Column("stay_duration_type", sa.String(length=50), nullable=True),
        sa.Column(
            "max_estimated_cost",
            sa.Numeric(precision=10, scale=2),
            nullable=True,
        ),
        sa.Column("requires_kid_friendly", sa.Boolean(), nullable=False),
        sa.Column("requires_wheelchair_accessible", sa.Boolean(), nullable=False),
        sa.Column("requires_pet_friendly", sa.Boolean(), nullable=False),
        sa.Column("requires_elderly_friendly", sa.Boolean(), nullable=False),
        sa.Column("family_friendly", sa.Boolean(), nullable=True),
        sa.Column("couple_friendly", sa.Boolean(), nullable=True),
        sa.Column("group_friendly", sa.Boolean(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "max_estimated_cost IS NULL OR max_estimated_cost >= 0",
            name=op.f("ck_user_preference_signals_max_estimated_cost_non_negative"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.user_id"],
            name=op.f("fk_user_preference_signals_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "preference_signal_id",
            name=op.f("pk_user_preference_signals"),
        ),
    )
    op.create_index(
        op.f("ix_user_preference_signals_preference_signal_id"),
        "user_preference_signals",
        ["preference_signal_id"],
    )
    op.create_index(
        op.f("ix_user_preference_signals_user_id"),
        "user_preference_signals",
        ["user_id"],
    )

    op.create_table(
        "destination_interactions",
        sa.Column("interaction_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("destination_id", sa.Integer(), nullable=False),
        sa.Column("interaction_type", sa.String(length=50), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "interaction_type IN ('view', 'save', 'rate', 'add_to_itinerary')",
            name=op.f("ck_destination_interactions_interaction_type"),
        ),
        sa.CheckConstraint(
            "(interaction_type = 'rate' AND rating BETWEEN 1 AND 5) OR "
            "(interaction_type != 'rate' AND rating IS NULL)",
            name=op.f("ck_destination_interactions_rating_matches_type"),
        ),
        sa.ForeignKeyConstraint(
            ["destination_id"],
            ["destinations.destination_id"],
            name=op.f("fk_destination_interactions_destination_id_destinations"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.user_id"],
            name=op.f("fk_destination_interactions_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "interaction_id",
            name=op.f("pk_destination_interactions"),
        ),
    )
    op.create_index(
        op.f("ix_destination_interactions_destination_id"),
        "destination_interactions",
        ["destination_id"],
    )
    op.create_index(
        op.f("ix_destination_interactions_interaction_id"),
        "destination_interactions",
        ["interaction_id"],
    )
    op.create_index(
        op.f("ix_destination_interactions_interaction_type"),
        "destination_interactions",
        ["interaction_type"],
    )
    op.create_index(
        "ix_destination_interactions_user_destination",
        "destination_interactions",
        ["user_id", "destination_id"],
    )
    op.create_index(
        op.f("ix_destination_interactions_user_id"),
        "destination_interactions",
        ["user_id"],
    )

    op.create_table(
        "destination_popularity",
        sa.Column("destination_id", sa.Integer(), nullable=False),
        sa.Column(
            "view_count",
            sa.Integer(),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column(
            "save_count",
            sa.Integer(),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column(
            "rating_count",
            sa.Integer(),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column(
            "rating_sum",
            sa.Integer(),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column(
            "average_rating",
            sa.Numeric(precision=3, scale=2),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column(
            "add_to_itinerary_count",
            sa.Integer(),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column(
            "popularity_score",
            sa.Numeric(precision=10, scale=2),
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
        sa.ForeignKeyConstraint(
            ["destination_id"],
            ["destinations.destination_id"],
            name=op.f("fk_destination_popularity_destination_id_destinations"),
            ondelete="CASCADE",
        ),
        sa.CheckConstraint(
            "view_count >= 0",
            name=op.f("ck_destination_popularity_view_count_non_negative"),
        ),
        sa.CheckConstraint(
            "save_count >= 0",
            name=op.f("ck_destination_popularity_save_count_non_negative"),
        ),
        sa.CheckConstraint(
            "rating_count >= 0",
            name=op.f("ck_destination_popularity_rating_count_non_negative"),
        ),
        sa.CheckConstraint(
            "rating_sum >= 0",
            name=op.f("ck_destination_popularity_rating_sum_non_negative"),
        ),
        sa.CheckConstraint(
            "average_rating >= 0",
            name=op.f("ck_destination_popularity_average_rating_non_negative"),
        ),
        sa.CheckConstraint(
            "add_to_itinerary_count >= 0",
            name=op.f(
                "ck_destination_popularity_add_to_itinerary_count_non_negative",
            ),
        ),
        sa.CheckConstraint(
            "popularity_score >= 0",
            name=op.f("ck_destination_popularity_popularity_score_non_negative"),
        ),
        sa.PrimaryKeyConstraint(
            "destination_id",
            name=op.f("pk_destination_popularity"),
        ),
    )


def downgrade() -> None:
    op.drop_table("destination_popularity")

    op.drop_index(
        op.f("ix_destination_interactions_user_id"),
        table_name="destination_interactions",
    )
    op.drop_index(
        "ix_destination_interactions_user_destination",
        table_name="destination_interactions",
    )
    op.drop_index(
        op.f("ix_destination_interactions_interaction_type"),
        table_name="destination_interactions",
    )
    op.drop_index(
        op.f("ix_destination_interactions_interaction_id"),
        table_name="destination_interactions",
    )
    op.drop_index(
        op.f("ix_destination_interactions_destination_id"),
        table_name="destination_interactions",
    )
    op.drop_table("destination_interactions")

    op.drop_index(
        op.f("ix_user_preference_signals_user_id"),
        table_name="user_preference_signals",
    )
    op.drop_index(
        op.f("ix_user_preference_signals_preference_signal_id"),
        table_name="user_preference_signals",
    )
    op.drop_table("user_preference_signals")
