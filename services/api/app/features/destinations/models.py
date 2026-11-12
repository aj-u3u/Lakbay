from datetime import datetime
from decimal import Decimal

from geoalchemy2 import Geography
from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Destination(Base):
    __tablename__ = "destinations"
    __table_args__ = (
        CheckConstraint("lat >= -90 AND lat <= 90", name="ck_destinations_lat_range"),
        CheckConstraint(
            "lng >= -180 AND lng <= 180",
            name="ck_destinations_lng_range",
        ),
        CheckConstraint(
            "(arrival_lat IS NULL AND arrival_lng IS NULL) OR "
            "(arrival_lat IS NOT NULL AND arrival_lng IS NOT NULL)",
            name="ck_destinations_arrival_pair",
        ),
        CheckConstraint(
            "arrival_lat IS NULL OR (arrival_lat >= -90 AND arrival_lat <= 90)",
            name="ck_destinations_arrival_lat_range",
        ),
        CheckConstraint(
            "arrival_lng IS NULL OR (arrival_lng >= -180 AND arrival_lng <= 180)",
            name="ck_destinations_arrival_lng_range",
        ),
        CheckConstraint(
            "route_ready = false OR "
            "(arrival_lat IS NOT NULL AND arrival_lng IS NOT NULL AND "
            "arrival_source_url IS NOT NULL AND arrival_verified_at IS NOT NULL)",
            name="ck_destinations_route_ready_arrival",
        ),
        CheckConstraint(
            "estimated_cost >= 0",
            name="ck_destinations_estimated_cost_non_negative",
        ),
        Index("ix_destinations_geom", "geom", postgresql_using="gist"),
    )

    destination_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(255), index=True)
    description: Mapped[str | None] = mapped_column(Text)
    district: Mapped[str | None] = mapped_column(String(255), index=True)
    location: Mapped[str | None] = mapped_column(String(500))
    category: Mapped[str | None] = mapped_column(String(500), index=True)
    vibes: Mapped[str | None] = mapped_column(String(500))
    activities: Mapped[str | None] = mapped_column(Text)
    lat: Mapped[float] = mapped_column(nullable=False)
    lng: Mapped[float] = mapped_column(nullable=False)
    arrival_lat: Mapped[float | None] = mapped_column(nullable=True)
    arrival_lng: Mapped[float | None] = mapped_column(nullable=True)
    arrival_source_url: Mapped[str | None] = mapped_column(String(2048))
    arrival_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    route_ready: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    geom: Mapped[object | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False),
    )
    estimated_cost: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    entrance_fee: Mapped[str | None] = mapped_column(String(255))
    overnight_fee: Mapped[str | None] = mapped_column(String(255))
    operating_hours: Mapped[str | None] = mapped_column(String(255))
    best_time_to_visit: Mapped[str | None] = mapped_column(Text)
    how_to_get_there: Mapped[str | None] = mapped_column(Text)
    estimated_travel_time: Mapped[str | None] = mapped_column(Text)
    travel_notes: Mapped[str | None] = mapped_column(Text)
    what_to_bring: Mapped[str | None] = mapped_column(Text)
    is_kid_friendly: Mapped[bool] = mapped_column(Boolean, default=False)
    is_wheelchair_accessible: Mapped[bool] = mapped_column(Boolean, default=False)
    is_pet_friendly: Mapped[bool] = mapped_column(Boolean, default=False)
    is_elderly_friendly: Mapped[bool] = mapped_column(Boolean, default=False)
    family_friendly: Mapped[bool] = mapped_column(Boolean, default=False)
    couple_friendly: Mapped[bool] = mapped_column(Boolean, default=False)
    group_friendly: Mapped[bool] = mapped_column(Boolean, default=False)
    budget_class: Mapped[str | None] = mapped_column(String(50), index=True)
    crowd_level: Mapped[str | None] = mapped_column(String(50))
    difficulty_level: Mapped[str | None] = mapped_column(String(50), index=True)
    stay_duration_type: Mapped[str | None] = mapped_column(String(50))
    transport_accessibility: Mapped[str | None] = mapped_column(String(100))
    image_url: Mapped[str | None] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    accommodations: Mapped[list["Accommodation"]] = relationship(
        back_populates="destination",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    transportations: Mapped[list["Transportation"]] = relationship(
        back_populates="destination",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class DestinationCandidate(Base):
    """Unpublished OSM place awaiting an administrator's visitor review."""

    __tablename__ = "destination_candidates"
    __table_args__ = (
        UniqueConstraint("osm_type", "osm_id", name="uq_destination_candidates_osm_identity"),
        CheckConstraint("lat >= -90 AND lat <= 90", name="ck_destination_candidates_lat_range"),
        CheckConstraint("lng >= -180 AND lng <= 180", name="ck_destination_candidates_lng_range"),
        CheckConstraint("estimated_cost IS NULL OR estimated_cost >= 0", name="ck_destination_candidates_cost_non_negative"),
        CheckConstraint("review_status IN ('staged', 'rejected', 'published')", name="ck_destination_candidates_review_status"),
        Index("ix_destination_candidates_review_status", "review_status"),
    )

    candidate_id: Mapped[int] = mapped_column(primary_key=True)
    osm_type: Mapped[str] = mapped_column(String(16), nullable=False)
    osm_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    osm_url: Mapped[str] = mapped_column(String(2048), nullable=False)
    source_area: Mapped[str] = mapped_column(String(100), nullable=False)
    source_tag: Mapped[str] = mapped_column(String(255), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    lat: Mapped[float] = mapped_column(nullable=False)
    lng: Mapped[float] = mapped_column(nullable=False)
    suggested_category: Mapped[str | None] = mapped_column(String(500))
    category: Mapped[str | None] = mapped_column(String(500))
    visitor_purpose: Mapped[str | None] = mapped_column(Text)
    description: Mapped[str | None] = mapped_column(Text)
    district: Mapped[str | None] = mapped_column(String(255))
    location: Mapped[str | None] = mapped_column(String(500))
    vibes: Mapped[str | None] = mapped_column(String(500))
    activities: Mapped[str | None] = mapped_column(Text)
    estimated_cost: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    entrance_fee: Mapped[str | None] = mapped_column(String(255))
    overnight_fee: Mapped[str | None] = mapped_column(String(255))
    operating_hours: Mapped[str | None] = mapped_column(String(255))
    access_policy: Mapped[str | None] = mapped_column(String(20))
    access_source_url: Mapped[str | None] = mapped_column(String(2048))
    access_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    review_status: Mapped[str] = mapped_column(String(20), nullable=False, default="staged", server_default="staged")
    review_notes: Mapped[str | None] = mapped_column(Text)
    destination_id: Mapped[int | None] = mapped_column(ForeignKey("destinations.destination_id"), unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
