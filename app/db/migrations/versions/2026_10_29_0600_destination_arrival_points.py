"""Store separately verified visitor arrival points for routing.

Revision ID: 2026_10_29_0600
Revises: 2026_10_18_0500
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "2026_10_29_0600"
down_revision: str | Sequence[str] | None = "2026_10_18_0500"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("destinations", sa.Column("arrival_lat", sa.Float(), nullable=True))
    op.add_column("destinations", sa.Column("arrival_lng", sa.Float(), nullable=True))
    op.add_column("destinations", sa.Column("arrival_source_url", sa.String(length=2048), nullable=True))
    op.add_column(
        "destinations",
        sa.Column("arrival_verified_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "destinations",
        sa.Column("route_ready", sa.Boolean(), server_default=sa.false(), nullable=False),
    )
    op.create_check_constraint(
        "ck_destinations_arrival_pair",
        "destinations",
        "(arrival_lat IS NULL AND arrival_lng IS NULL) OR "
        "(arrival_lat IS NOT NULL AND arrival_lng IS NOT NULL)",
    )
    op.create_check_constraint(
        "ck_destinations_arrival_lat_range",
        "destinations",
        "arrival_lat IS NULL OR (arrival_lat >= -90 AND arrival_lat <= 90)",
    )
    op.create_check_constraint(
        "ck_destinations_arrival_lng_range",
        "destinations",
        "arrival_lng IS NULL OR (arrival_lng >= -180 AND arrival_lng <= 180)",
    )
    op.create_check_constraint(
        "ck_destinations_route_ready_arrival",
        "destinations",
        "route_ready = false OR "
        "(arrival_lat IS NOT NULL AND arrival_lng IS NOT NULL AND "
        "arrival_source_url IS NOT NULL AND arrival_verified_at IS NOT NULL)",
    )
    op.add_column("trip_routes", sa.Column("polyline", sa.Text(), nullable=True))
    op.add_column("trip_routes", sa.Column("polyline_encoding", sa.String(length=20), nullable=True))
    op.add_column(
        "trip_routes",
        sa.Column("arrival_points_verified", sa.Boolean(), server_default=sa.false(), nullable=False),
    )


def downgrade() -> None:
    op.drop_column("trip_routes", "arrival_points_verified")
    op.drop_column("trip_routes", "polyline_encoding")
    op.drop_column("trip_routes", "polyline")
    op.drop_constraint("ck_destinations_route_ready_arrival", "destinations", type_="check")
    op.drop_constraint("ck_destinations_arrival_lng_range", "destinations", type_="check")
    op.drop_constraint("ck_destinations_arrival_lat_range", "destinations", type_="check")
    op.drop_constraint("ck_destinations_arrival_pair", "destinations", type_="check")
    op.drop_column("destinations", "route_ready")
    op.drop_column("destinations", "arrival_verified_at")
    op.drop_column("destinations", "arrival_source_url")
    op.drop_column("destinations", "arrival_lng")
    op.drop_column("destinations", "arrival_lat")
