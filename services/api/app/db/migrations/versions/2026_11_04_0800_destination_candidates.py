"""Add unpublished OSM destination review queue.

Revision ID: 2026_11_04_0800
Revises: 95bb71db451f
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "2026_11_04_0800"
down_revision: str | Sequence[str] | None = "95bb71db451f"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "destination_candidates",
        sa.Column("candidate_id", sa.Integer(), primary_key=True),
        sa.Column("osm_type", sa.String(16), nullable=False),
        sa.Column("osm_id", sa.BigInteger(), nullable=False),
        sa.Column("osm_url", sa.String(2048), nullable=False),
        sa.Column("source_area", sa.String(100), nullable=False),
        sa.Column("source_tag", sa.String(255), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("lat", sa.Float(), nullable=False),
        sa.Column("lng", sa.Float(), nullable=False),
        sa.Column("suggested_category", sa.String(500)),
        sa.Column("category", sa.String(500)),
        sa.Column("visitor_purpose", sa.Text()),
        sa.Column("description", sa.Text()),
        sa.Column("district", sa.String(255)),
        sa.Column("location", sa.String(500)),
        sa.Column("activities", sa.Text()),
        sa.Column("estimated_cost", sa.Numeric(10, 2)),
        sa.Column("entrance_fee", sa.String(255)),
        sa.Column("overnight_fee", sa.String(255)),
        sa.Column("operating_hours", sa.String(255)),
        sa.Column("access_policy", sa.String(20)),
        sa.Column("access_source_url", sa.String(2048)),
        sa.Column("access_verified_at", sa.DateTime(timezone=True)),
        sa.Column("review_status", sa.String(20), nullable=False, server_default="staged"),
        sa.Column("review_notes", sa.Text()),
        sa.Column("destination_id", sa.Integer(), sa.ForeignKey("destinations.destination_id"), unique=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("lat >= -90 AND lat <= 90", name="ck_destination_candidates_lat_range"),
        sa.CheckConstraint("lng >= -180 AND lng <= 180", name="ck_destination_candidates_lng_range"),
        sa.CheckConstraint("estimated_cost IS NULL OR estimated_cost >= 0", name="ck_destination_candidates_cost_non_negative"),
        sa.CheckConstraint("review_status IN ('staged', 'rejected', 'published')", name="ck_destination_candidates_review_status"),
        sa.UniqueConstraint("osm_type", "osm_id", name="uq_destination_candidates_osm_identity"),
    )
    op.create_index("ix_destination_candidates_review_status", "destination_candidates", ["review_status"])


def downgrade() -> None:
    op.drop_index("ix_destination_candidates_review_status", table_name="destination_candidates")
    op.drop_table("destination_candidates")
