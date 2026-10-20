from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Trip(Base):
    __tablename__ = "trips"
    __table_args__ = (
        CheckConstraint(
            "status IN ('planned', 'ongoing', 'completed', 'archived')",
            name="ck_trips_status",
        ),
        CheckConstraint("traveler_count >= 1", name="ck_trips_traveler_count_positive"),
        CheckConstraint("total_budget >= 0", name="ck_trips_total_budget_non_negative"),
        CheckConstraint(
            "estimated_total_cost >= 0",
            name="ck_trips_estimated_total_cost_non_negative",
        ),
        CheckConstraint(
            "end_date IS NULL OR start_date IS NULL OR end_date >= start_date",
            name="ck_trips_end_date_after_start_date",
        ),
    )

    trip_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    owner_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        index=True,
    )
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text)
    start_date: Mapped[date | None] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date)
    traveler_count: Mapped[int] = mapped_column(Integer, default=1)
    total_budget: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=0)
    estimated_total_cost: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=0)
    status: Mapped[str] = mapped_column(
        String(50),
        default="planned",
        server_default=text("'planned'"),
        index=True,
    )
    notes: Mapped[str | None] = mapped_column(Text)
    planning_snapshot: Mapped[dict | None] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    destinations: Mapped[list["TripDestination"]] = relationship(
        back_populates="trip",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    itinerary_days: Mapped[list["TripItineraryDay"]] = relationship(
        back_populates="trip",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    route: Mapped["TripRoute | None"] = relationship(
        back_populates="trip",
        cascade="all, delete-orphan",
        passive_deletes=True,
        uselist=False,
    )
    members: Mapped[list["TripMember"]] = relationship(
        back_populates="trip",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    tasks: Mapped[list["TripTask"]] = relationship(
        back_populates="trip",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class TripDestination(Base):
    __tablename__ = "trip_destinations"
    __table_args__ = (
        UniqueConstraint(
            "trip_id",
            "destination_id",
            name="uq_trip_destinations_trip_id_destination_id",
        ),
        UniqueConstraint(
            "trip_id",
            "stop_order",
            name="uq_trip_destinations_trip_id_stop_order",
        ),
        CheckConstraint("stop_order >= 1", name="ck_trip_destinations_stop_order_positive"),
    )

    trip_destination_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    trip_id: Mapped[int] = mapped_column(
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        index=True,
    )
    destination_id: Mapped[int] = mapped_column(
        ForeignKey("destinations.destination_id", ondelete="RESTRICT"),
        index=True,
    )
    stop_order: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    trip: Mapped["Trip"] = relationship(back_populates="destinations")
    destination: Mapped["Destination"] = relationship()


class TripItineraryDay(Base):
    __tablename__ = "trip_itinerary_days"
    __table_args__ = (
        UniqueConstraint(
            "trip_id",
            "day_number",
            name="uq_trip_itinerary_days_trip_id_day_number",
        ),
        CheckConstraint(
            "day_number >= 1",
            name="ck_trip_itinerary_days_day_number_positive",
        ),
    )

    trip_itinerary_day_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    trip_id: Mapped[int] = mapped_column(
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        index=True,
    )
    day_number: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(255))
    summary: Mapped[str | None] = mapped_column(Text)

    trip: Mapped["Trip"] = relationship(back_populates="itinerary_days")
    activities: Mapped[list["TripItineraryActivity"]] = relationship(
        back_populates="day",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class TripItineraryActivity(Base):
    __tablename__ = "trip_itinerary_activities"
    __table_args__ = (
        UniqueConstraint(
            "trip_itinerary_day_id",
            "activity_order",
            name="uq_trip_itinerary_activities_day_id_activity_order",
        ),
        CheckConstraint(
            "activity_order >= 1",
            name="ck_trip_itinerary_activities_activity_order_positive",
        ),
        CheckConstraint(
            "estimated_cost >= 0",
            name="ck_trip_itinerary_activities_estimated_cost_non_negative",
        ),
    )

    trip_itinerary_activity_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    trip_itinerary_day_id: Mapped[int] = mapped_column(
        ForeignKey("trip_itinerary_days.trip_itinerary_day_id", ondelete="CASCADE"),
        index=True,
    )
    destination_id: Mapped[int | None] = mapped_column(
        ForeignKey("destinations.destination_id", ondelete="SET NULL"),
        index=True,
    )
    accommodation_id: Mapped[int | None] = mapped_column(
        ForeignKey("accommodations.accommodation_id", ondelete="SET NULL"),
        index=True,
    )
    transportation_id: Mapped[int | None] = mapped_column(
        ForeignKey("transportations.transportation_id", ondelete="SET NULL"),
        index=True,
    )
    activity_order: Mapped[int] = mapped_column(Integer)
    time: Mapped[str | None] = mapped_column(String(20))
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text)
    estimated_cost: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=0)
    notes: Mapped[str | None] = mapped_column(Text)

    day: Mapped["TripItineraryDay"] = relationship(back_populates="activities")
    destination: Mapped["Destination | None"] = relationship()
    accommodation: Mapped["Accommodation | None"] = relationship()
    transportation: Mapped["Transportation | None"] = relationship()


class TripRoute(Base):
    __tablename__ = "trip_routes"

    trip_route_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    trip_id: Mapped[int] = mapped_column(
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        unique=True,
        index=True,
    )
    travel_mode: Mapped[str] = mapped_column(String(50))
    route_provider: Mapped[str] = mapped_column(String(100))
    is_estimated: Mapped[bool] = mapped_column()
    total_distance_km: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    total_duration_minutes: Mapped[int] = mapped_column(Integer)
    stops: Mapped[list] = mapped_column(JSON)
    legs: Mapped[list] = mapped_column(JSON)
    warnings: Mapped[list] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    trip: Mapped["Trip"] = relationship(back_populates="route")


class TripMember(Base):
    __tablename__ = "trip_members"
    __table_args__ = (
        UniqueConstraint(
            "trip_id",
            "user_id",
            name="uq_trip_members_trip_id_user_id",
        ),
        UniqueConstraint(
            "trip_id",
            "trip_member_id",
            name="uq_trip_members_trip_id_trip_member_id",
        ),
        CheckConstraint(
            "role IN ('owner', 'organizer', 'member')",
            name="ck_trip_members_role",
        ),
        CheckConstraint(
            "status IN ('active', 'removed')",
            name="ck_trip_members_status",
        ),
    )

    trip_member_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    trip_id: Mapped[int] = mapped_column(
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        index=True,
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        index=True,
    )
    role: Mapped[str] = mapped_column(String(50), default="member")
    status: Mapped[str] = mapped_column(String(50), default="active", index=True)
    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    trip: Mapped["Trip"] = relationship(back_populates="members")
    user: Mapped["User"] = relationship()
    assigned_tasks: Mapped[list["TripTask"]] = relationship(
        back_populates="assigned_member",
    )


class TripTask(Base):
    __tablename__ = "trip_tasks"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'ongoing', 'completed')",
            name="ck_trip_tasks_status",
        ),
    )

    trip_task_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    trip_id: Mapped[int] = mapped_column(
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        index=True,
    )
    created_by_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="RESTRICT"),
        index=True,
    )
    assigned_trip_member_id: Mapped[int | None] = mapped_column(
        ForeignKey("trip_members.trip_member_id", ondelete="SET NULL"),
        index=True,
    )
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(50), default="pending", index=True)
    due_date: Mapped[date | None] = mapped_column(Date)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    trip: Mapped["Trip"] = relationship(back_populates="tasks")
    created_by: Mapped["User"] = relationship(foreign_keys=[created_by_user_id])
    assigned_member: Mapped["TripMember | None"] = relationship(
        back_populates="assigned_tasks",
        foreign_keys=[assigned_trip_member_id],
    )
