from datetime import datetime
from decimal import Decimal

from geoalchemy2 import Geography
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Index,
    Numeric,
    String,
    Text,
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
    geom: Mapped[object | None] = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False),
    )
    estimated_cost: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=0)
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
