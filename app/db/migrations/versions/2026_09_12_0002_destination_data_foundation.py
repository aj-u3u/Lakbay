"""destination data foundation

Revision ID: 0002_destination_data_foundation
Revises: a1aa9ddabfe3
Create Date: 2026-09-12 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import geoalchemy2
import sqlalchemy as sa


revision: str = "0002_destination_data_foundation"
down_revision: str | Sequence[str] | None = "a1aa9ddabfe3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")

    op.create_table(
        "destinations",
        sa.Column("destination_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("district", sa.String(length=255), nullable=True),
        sa.Column("location", sa.String(length=500), nullable=True),
        sa.Column("category", sa.String(length=500), nullable=True),
        sa.Column("vibes", sa.String(length=500), nullable=True),
        sa.Column("activities", sa.Text(), nullable=True),
        sa.Column("lat", sa.Float(), nullable=False),
        sa.Column("lng", sa.Float(), nullable=False),
        sa.Column(
            "geom",
            geoalchemy2.Geography(
                geometry_type="POINT",
                srid=4326,
                spatial_index=False,
            ),
            nullable=True,
        ),
        sa.Column(
            "estimated_cost",
            sa.Numeric(precision=10, scale=2),
            nullable=False,
        ),
        sa.Column("entrance_fee", sa.String(length=255), nullable=True),
        sa.Column("overnight_fee", sa.String(length=255), nullable=True),
        sa.Column("operating_hours", sa.String(length=255), nullable=True),
        sa.Column("best_time_to_visit", sa.Text(), nullable=True),
        sa.Column("how_to_get_there", sa.Text(), nullable=True),
        sa.Column("estimated_travel_time", sa.Text(), nullable=True),
        sa.Column("travel_notes", sa.Text(), nullable=True),
        sa.Column("what_to_bring", sa.Text(), nullable=True),
        sa.Column("is_kid_friendly", sa.Boolean(), nullable=False),
        sa.Column("is_wheelchair_accessible", sa.Boolean(), nullable=False),
        sa.Column("is_pet_friendly", sa.Boolean(), nullable=False),
        sa.Column("is_elderly_friendly", sa.Boolean(), nullable=False),
        sa.Column("family_friendly", sa.Boolean(), nullable=False),
        sa.Column("couple_friendly", sa.Boolean(), nullable=False),
        sa.Column("group_friendly", sa.Boolean(), nullable=False),
        sa.Column("budget_class", sa.String(length=50), nullable=True),
        sa.Column("crowd_level", sa.String(length=50), nullable=True),
        sa.Column("difficulty_level", sa.String(length=50), nullable=True),
        sa.Column("stay_duration_type", sa.String(length=50), nullable=True),
        sa.Column("transport_accessibility", sa.String(length=100), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
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
            "lat >= -90 AND lat <= 90",
            name=op.f("ck_destinations_lat_range"),
        ),
        sa.CheckConstraint(
            "lng >= -180 AND lng <= 180",
            name=op.f("ck_destinations_lng_range"),
        ),
        sa.CheckConstraint(
            "estimated_cost >= 0",
            name=op.f("ck_destinations_estimated_cost_non_negative"),
        ),
        sa.PrimaryKeyConstraint("destination_id", name=op.f("pk_destinations")),
    )
    op.create_index(op.f("ix_destinations_budget_class"), "destinations", ["budget_class"])
    op.create_index(op.f("ix_destinations_category"), "destinations", ["category"])
    op.create_index(op.f("ix_destinations_destination_id"), "destinations", ["destination_id"])
    op.create_index(op.f("ix_destinations_difficulty_level"), "destinations", ["difficulty_level"])
    op.create_index(op.f("ix_destinations_district"), "destinations", ["district"])
    op.create_index("ix_destinations_geom", "destinations", ["geom"], postgresql_using="gist")
    op.create_index(op.f("ix_destinations_is_active"), "destinations", ["is_active"])
    op.create_index(op.f("ix_destinations_name"), "destinations", ["name"])

    op.create_table(
        "accommodations",
        sa.Column("accommodation_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("destination_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("room_type", sa.String(length=255), nullable=False),
        sa.Column("price", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("capacity", sa.Integer(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("is_available", sa.Boolean(), nullable=False),
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
            name=op.f("fk_accommodations_destination_id_destinations"),
            ondelete="CASCADE",
        ),
        sa.CheckConstraint(
            "price >= 0",
            name=op.f("ck_accommodations_price_non_negative"),
        ),
        sa.CheckConstraint(
            "capacity >= 1",
            name=op.f("ck_accommodations_capacity_positive"),
        ),
        sa.PrimaryKeyConstraint("accommodation_id", name=op.f("pk_accommodations")),
    )
    op.create_index(op.f("ix_accommodations_accommodation_id"), "accommodations", ["accommodation_id"])
    op.create_index(op.f("ix_accommodations_destination_id"), "accommodations", ["destination_id"])
    op.create_index(op.f("ix_accommodations_is_available"), "accommodations", ["is_available"])

    op.create_table(
        "transportations",
        sa.Column("transportation_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("destination_id", sa.Integer(), nullable=False),
        sa.Column("vehicle_type", sa.String(length=100), nullable=False),
        sa.Column("transport_mode", sa.String(length=100), nullable=False),
        sa.Column("route_from", sa.String(length=255), nullable=False),
        sa.Column("route_to", sa.String(length=255), nullable=False),
        sa.Column("price", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("duration_minutes", sa.Integer(), nullable=True),
        sa.Column("duration_text", sa.String(length=100), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("is_available", sa.Boolean(), nullable=False),
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
            name=op.f("fk_transportations_destination_id_destinations"),
            ondelete="CASCADE",
        ),
        sa.CheckConstraint(
            "price >= 0",
            name=op.f("ck_transportations_price_non_negative"),
        ),
        sa.CheckConstraint(
            "duration_minutes IS NULL OR duration_minutes >= 0",
            name=op.f("ck_transportations_duration_minutes_non_negative"),
        ),
        sa.PrimaryKeyConstraint("transportation_id", name=op.f("pk_transportations")),
    )
    op.create_index(op.f("ix_transportations_destination_id"), "transportations", ["destination_id"])
    op.create_index(op.f("ix_transportations_is_available"), "transportations", ["is_available"])
    op.create_index(op.f("ix_transportations_transport_mode"), "transportations", ["transport_mode"])
    op.create_index(op.f("ix_transportations_transportation_id"), "transportations", ["transportation_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_transportations_transportation_id"), table_name="transportations")
    op.drop_index(op.f("ix_transportations_transport_mode"), table_name="transportations")
    op.drop_index(op.f("ix_transportations_is_available"), table_name="transportations")
    op.drop_index(op.f("ix_transportations_destination_id"), table_name="transportations")
    op.drop_table("transportations")

    op.drop_index(op.f("ix_accommodations_is_available"), table_name="accommodations")
    op.drop_index(op.f("ix_accommodations_destination_id"), table_name="accommodations")
    op.drop_index(op.f("ix_accommodations_accommodation_id"), table_name="accommodations")
    op.drop_table("accommodations")

    op.drop_index(op.f("ix_destinations_name"), table_name="destinations")
    op.drop_index(op.f("ix_destinations_is_active"), table_name="destinations")
    op.drop_index("ix_destinations_geom", table_name="destinations", postgresql_using="gist")
    op.drop_index(op.f("ix_destinations_district"), table_name="destinations")
    op.drop_index(op.f("ix_destinations_difficulty_level"), table_name="destinations")
    op.drop_index(op.f("ix_destinations_destination_id"), table_name="destinations")
    op.drop_index(op.f("ix_destinations_category"), table_name="destinations")
    op.drop_index(op.f("ix_destinations_budget_class"), table_name="destinations")
    op.drop_table("destinations")
