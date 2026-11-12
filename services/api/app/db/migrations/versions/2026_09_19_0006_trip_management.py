"""add trip management tables

Revision ID: 0006_trip_management
Revises: 0005_ai_generation_runs
Create Date: 2026-09-19 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0006_trip_management"
down_revision: str | Sequence[str] | None = "0005_ai_generation_runs"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "trips",
        sa.Column("trip_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("owner_user_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=True),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column("traveler_count", sa.Integer(), nullable=False),
        sa.Column("total_budget", sa.Numeric(10, 2), nullable=False),
        sa.Column("estimated_total_cost", sa.Numeric(10, 2), nullable=False),
        sa.Column(
            "status",
            sa.String(length=50),
            server_default=sa.text("'planned'"),
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
            "status IN ('planned', 'ongoing', 'completed', 'archived')",
            name=op.f("ck_trips_status"),
        ),
        sa.CheckConstraint(
            "traveler_count >= 1",
            name=op.f("ck_trips_traveler_count_positive"),
        ),
        sa.CheckConstraint(
            "total_budget >= 0",
            name=op.f("ck_trips_total_budget_non_negative"),
        ),
        sa.CheckConstraint(
            "estimated_total_cost >= 0",
            name=op.f("ck_trips_estimated_total_cost_non_negative"),
        ),
        sa.CheckConstraint(
            "end_date IS NULL OR start_date IS NULL OR end_date >= start_date",
            name=op.f("ck_trips_end_date_after_start_date"),
        ),
        sa.ForeignKeyConstraint(
            ["owner_user_id"],
            ["users.user_id"],
            name=op.f("fk_trips_owner_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("trip_id", name=op.f("pk_trips")),
    )
    op.create_index(op.f("ix_trips_owner_user_id"), "trips", ["owner_user_id"])
    op.create_index(op.f("ix_trips_status"), "trips", ["status"])
    op.create_index(op.f("ix_trips_trip_id"), "trips", ["trip_id"])

    op.create_table(
        "trip_destinations",
        sa.Column(
            "trip_destination_id",
            sa.Integer(),
            autoincrement=True,
            nullable=False,
        ),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("destination_id", sa.Integer(), nullable=False),
        sa.Column("stop_order", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "stop_order >= 1",
            name=op.f("ck_trip_destinations_stop_order_positive"),
        ),
        sa.ForeignKeyConstraint(
            ["destination_id"],
            ["destinations.destination_id"],
            name=op.f("fk_trip_destinations_destination_id_destinations"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.trip_id"],
            name=op.f("fk_trip_destinations_trip_id_trips"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "trip_destination_id",
            name=op.f("pk_trip_destinations"),
        ),
        sa.UniqueConstraint(
            "trip_id",
            "destination_id",
            name="uq_trip_destinations_trip_id_destination_id",
        ),
        sa.UniqueConstraint(
            "trip_id",
            "stop_order",
            name="uq_trip_destinations_trip_id_stop_order",
        ),
    )
    op.create_index(
        op.f("ix_trip_destinations_destination_id"),
        "trip_destinations",
        ["destination_id"],
    )
    op.create_index(
        op.f("ix_trip_destinations_trip_destination_id"),
        "trip_destinations",
        ["trip_destination_id"],
    )
    op.create_index(op.f("ix_trip_destinations_trip_id"), "trip_destinations", ["trip_id"])

    op.create_table(
        "trip_itinerary_days",
        sa.Column(
            "trip_itinerary_day_id",
            sa.Integer(),
            autoincrement=True,
            nullable=False,
        ),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("day_number", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("summary", sa.Text(), nullable=True),
        sa.CheckConstraint(
            "day_number >= 1",
            name=op.f("ck_trip_itinerary_days_day_number_positive"),
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.trip_id"],
            name=op.f("fk_trip_itinerary_days_trip_id_trips"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "trip_itinerary_day_id",
            name=op.f("pk_trip_itinerary_days"),
        ),
        sa.UniqueConstraint(
            "trip_id",
            "day_number",
            name="uq_trip_itinerary_days_trip_id_day_number",
        ),
    )
    op.create_index(
        op.f("ix_trip_itinerary_days_trip_id"),
        "trip_itinerary_days",
        ["trip_id"],
    )
    op.create_index(
        op.f("ix_trip_itinerary_days_trip_itinerary_day_id"),
        "trip_itinerary_days",
        ["trip_itinerary_day_id"],
    )

    op.create_table(
        "trip_routes",
        sa.Column("trip_route_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("trip_id", sa.Integer(), nullable=False),
        sa.Column("travel_mode", sa.String(length=50), nullable=False),
        sa.Column("route_provider", sa.String(length=100), nullable=False),
        sa.Column("is_estimated", sa.Boolean(), nullable=False),
        sa.Column("total_distance_km", sa.Numeric(10, 2), nullable=False),
        sa.Column("total_duration_minutes", sa.Integer(), nullable=False),
        sa.Column("stops", sa.JSON(), nullable=False),
        sa.Column("legs", sa.JSON(), nullable=False),
        sa.Column("warnings", sa.JSON(), nullable=False),
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
            ["trip_id"],
            ["trips.trip_id"],
            name=op.f("fk_trip_routes_trip_id_trips"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("trip_route_id", name=op.f("pk_trip_routes")),
    )
    op.create_index(op.f("ix_trip_routes_trip_id"), "trip_routes", ["trip_id"], unique=True)
    op.create_index(
        op.f("ix_trip_routes_trip_route_id"),
        "trip_routes",
        ["trip_route_id"],
    )

    op.create_table(
        "trip_itinerary_activities",
        sa.Column(
            "trip_itinerary_activity_id",
            sa.Integer(),
            autoincrement=True,
            nullable=False,
        ),
        sa.Column("trip_itinerary_day_id", sa.Integer(), nullable=False),
        sa.Column("destination_id", sa.Integer(), nullable=True),
        sa.Column("accommodation_id", sa.Integer(), nullable=True),
        sa.Column("transportation_id", sa.Integer(), nullable=True),
        sa.Column("activity_order", sa.Integer(), nullable=False),
        sa.Column("time", sa.String(length=20), nullable=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("estimated_cost", sa.Numeric(10, 2), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.CheckConstraint(
            "activity_order >= 1",
            name=op.f("ck_trip_itinerary_activities_activity_order_positive"),
        ),
        sa.CheckConstraint(
            "estimated_cost >= 0",
            name=op.f("ck_trip_itinerary_activities_estimated_cost_non_negative"),
        ),
        sa.ForeignKeyConstraint(
            ["accommodation_id"],
            ["accommodations.accommodation_id"],
            name=op.f(
                "fk_trip_itinerary_activities_accommodation_id_accommodations"
            ),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["destination_id"],
            ["destinations.destination_id"],
            name=op.f("fk_trip_itinerary_activities_destination_id_destinations"),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["transportation_id"],
            ["transportations.transportation_id"],
            name=op.f(
                "fk_trip_itinerary_activities_transportation_id_transportations"
            ),
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["trip_itinerary_day_id"],
            ["trip_itinerary_days.trip_itinerary_day_id"],
            name=op.f(
                "fk_trip_itinerary_activities_trip_itinerary_day_id_trip_itinerary_days"
            ),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "trip_itinerary_activity_id",
            name=op.f("pk_trip_itinerary_activities"),
        ),
        sa.UniqueConstraint(
            "trip_itinerary_day_id",
            "activity_order",
            name="uq_trip_itinerary_activities_day_id_activity_order",
        ),
    )
    op.create_index(
        op.f("ix_trip_itinerary_activities_accommodation_id"),
        "trip_itinerary_activities",
        ["accommodation_id"],
    )
    op.create_index(
        op.f("ix_trip_itinerary_activities_destination_id"),
        "trip_itinerary_activities",
        ["destination_id"],
    )
    op.create_index(
        op.f("ix_trip_itinerary_activities_transportation_id"),
        "trip_itinerary_activities",
        ["transportation_id"],
    )
    op.create_index(
        op.f("ix_trip_itinerary_activities_trip_itinerary_activity_id"),
        "trip_itinerary_activities",
        ["trip_itinerary_activity_id"],
    )
    op.create_index(
        op.f("ix_trip_itinerary_activities_trip_itinerary_day_id"),
        "trip_itinerary_activities",
        ["trip_itinerary_day_id"],
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_trip_itinerary_activities_trip_itinerary_day_id"),
        table_name="trip_itinerary_activities",
    )
    op.drop_index(
        op.f("ix_trip_itinerary_activities_trip_itinerary_activity_id"),
        table_name="trip_itinerary_activities",
    )
    op.drop_index(
        op.f("ix_trip_itinerary_activities_transportation_id"),
        table_name="trip_itinerary_activities",
    )
    op.drop_index(
        op.f("ix_trip_itinerary_activities_destination_id"),
        table_name="trip_itinerary_activities",
    )
    op.drop_index(
        op.f("ix_trip_itinerary_activities_accommodation_id"),
        table_name="trip_itinerary_activities",
    )
    op.drop_table("trip_itinerary_activities")

    op.drop_index(op.f("ix_trip_routes_trip_route_id"), table_name="trip_routes")
    op.drop_index(op.f("ix_trip_routes_trip_id"), table_name="trip_routes")
    op.drop_table("trip_routes")

    op.drop_index(
        op.f("ix_trip_itinerary_days_trip_itinerary_day_id"),
        table_name="trip_itinerary_days",
    )
    op.drop_index(op.f("ix_trip_itinerary_days_trip_id"), table_name="trip_itinerary_days")
    op.drop_table("trip_itinerary_days")

    op.drop_index(op.f("ix_trip_destinations_trip_id"), table_name="trip_destinations")
    op.drop_index(
        op.f("ix_trip_destinations_trip_destination_id"),
        table_name="trip_destinations",
    )
    op.drop_index(
        op.f("ix_trip_destinations_destination_id"),
        table_name="trip_destinations",
    )
    op.drop_table("trip_destinations")

    op.drop_index(op.f("ix_trips_trip_id"), table_name="trips")
    op.drop_index(op.f("ix_trips_status"), table_name="trips")
    op.drop_index(op.f("ix_trips_owner_user_id"), table_name="trips")
    op.drop_table("trips")
