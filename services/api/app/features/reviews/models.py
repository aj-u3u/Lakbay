from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class TripReview(Base):
    __tablename__ = "trip_reviews"
    __table_args__ = (
        CheckConstraint(
            "post_trip_rating BETWEEN 1 AND 5",
            name="ck_trip_reviews_post_trip_rating_range",
        ),
        CheckConstraint(
            "accuracy_rating BETWEEN 1 AND 5",
            name="ck_trip_reviews_accuracy_rating_range",
        ),
        CheckConstraint(
            "route_efficiency_rating BETWEEN 1 AND 5",
            name="ck_trip_reviews_route_efficiency_rating_range",
        ),
        CheckConstraint(
            "budget_adherence_rating BETWEEN 1 AND 5",
            name="ck_trip_reviews_budget_adherence_rating_range",
        ),
        CheckConstraint(
            "overall_experience_rating BETWEEN 1 AND 5",
            name="ck_trip_reviews_overall_experience_rating_range",
        ),
        CheckConstraint(
            "status IN ('active', 'deleted')",
            name="ck_trip_reviews_status",
        ),
        ForeignKeyConstraint(
            ["trip_id", "trip_member_id"],
            ["trip_members.trip_id", "trip_members.trip_member_id"],
            name="fk_trip_reviews_member_same_trip",
            ondelete="RESTRICT",
        ),
        ForeignKeyConstraint(
            ["trip_id", "user_id"],
            ["trip_members.trip_id", "trip_members.user_id"],
            name="fk_trip_reviews_user_same_trip",
            ondelete="RESTRICT",
        ),
        Index(
            "uq_trip_reviews_active_trip_user",
            "trip_id",
            "user_id",
            unique=True,
            postgresql_where=text("destination_id IS NULL AND status = 'active'"),
            sqlite_where=text("destination_id IS NULL AND status = 'active'"),
        ),
        Index(
            "uq_trip_reviews_active_destination_user",
            "trip_id",
            "user_id",
            "destination_id",
            unique=True,
            postgresql_where=text("destination_id IS NOT NULL AND status = 'active'"),
            sqlite_where=text("destination_id IS NOT NULL AND status = 'active'"),
        ),
    )

    trip_review_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    trip_id: Mapped[int] = mapped_column(
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        index=True,
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        index=True,
    )
    trip_member_id: Mapped[int] = mapped_column(index=True)
    destination_id: Mapped[int | None] = mapped_column(
        ForeignKey("destinations.destination_id", ondelete="SET NULL"),
        index=True,
    )
    post_trip_rating: Mapped[int] = mapped_column(Integer)
    accuracy_rating: Mapped[int] = mapped_column(Integer)
    route_efficiency_rating: Mapped[int] = mapped_column(Integer)
    budget_adherence_rating: Mapped[int] = mapped_column(Integer)
    overall_experience_rating: Mapped[int] = mapped_column(Integer)
    comments: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(
        String(50),
        default="active",
        server_default=text("'active'"),
        index=True,
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

    trip: Mapped["Trip"] = relationship()
    user: Mapped["User"] = relationship(foreign_keys=[user_id])
    member: Mapped["TripMember"] = relationship(foreign_keys=[trip_member_id])
    destination: Mapped["Destination | None"] = relationship()
