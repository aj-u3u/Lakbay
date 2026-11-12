from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    Numeric,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class UserPreferenceSignal(Base):
    __tablename__ = "user_preference_signals"
    __table_args__ = (
        CheckConstraint(
            "max_estimated_cost IS NULL OR max_estimated_cost >= 0",
            name="ck_user_preference_signals_max_estimated_cost_non_negative",
        ),
    )

    preference_signal_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        index=True,
    )
    preferred_categories: Mapped[list[str]] = mapped_column(JSON, default=list)
    preferred_vibes: Mapped[list[str]] = mapped_column(JSON, default=list)
    preferred_activities: Mapped[list[str]] = mapped_column(JSON, default=list)
    preferred_districts: Mapped[list[str]] = mapped_column(JSON, default=list)
    budget_class: Mapped[str | None] = mapped_column(String(50))
    difficulty_level: Mapped[str | None] = mapped_column(String(50))
    stay_duration_type: Mapped[str | None] = mapped_column(String(50))
    max_estimated_cost: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    requires_kid_friendly: Mapped[bool] = mapped_column(Boolean, default=False)
    requires_wheelchair_accessible: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
    )
    requires_pet_friendly: Mapped[bool] = mapped_column(Boolean, default=False)
    requires_elderly_friendly: Mapped[bool] = mapped_column(Boolean, default=False)
    family_friendly: Mapped[bool | None] = mapped_column(Boolean)
    couple_friendly: Mapped[bool | None] = mapped_column(Boolean)
    group_friendly: Mapped[bool | None] = mapped_column(Boolean)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class DestinationInteraction(Base):
    __tablename__ = "destination_interactions"
    __table_args__ = (
        CheckConstraint(
            "interaction_type IN ('view', 'save', 'rate', 'add_to_itinerary')",
            name="ck_destination_interactions_interaction_type",
        ),
        CheckConstraint(
            "(interaction_type = 'rate' AND rating BETWEEN 1 AND 5) OR "
            "(interaction_type != 'rate' AND rating IS NULL)",
            name="ck_destination_interactions_rating_matches_type",
        ),
        Index(
            "ix_destination_interactions_user_destination",
            "user_id",
            "destination_id",
        ),
        Index(
            "uq_destination_interactions_user_destination_non_view_type",
            "user_id",
            "destination_id",
            "interaction_type",
            unique=True,
            postgresql_where=text("interaction_type != 'view'"),
            sqlite_where=text("interaction_type != 'view'"),
        ),
    )

    interaction_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        index=True,
    )
    destination_id: Mapped[int] = mapped_column(
        ForeignKey("destinations.destination_id", ondelete="CASCADE"),
        index=True,
    )
    interaction_type: Mapped[str] = mapped_column(String(50), index=True)
    rating: Mapped[int | None] = mapped_column(Integer)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )


class DestinationPopularity(Base):
    __tablename__ = "destination_popularity"
    __table_args__ = (
        CheckConstraint(
            "view_count >= 0",
            name="ck_destination_popularity_view_count_non_negative",
        ),
        CheckConstraint(
            "save_count >= 0",
            name="ck_destination_popularity_save_count_non_negative",
        ),
        CheckConstraint(
            "rating_count >= 0",
            name="ck_destination_popularity_rating_count_non_negative",
        ),
        CheckConstraint(
            "rating_sum >= 0",
            name="ck_destination_popularity_rating_sum_non_negative",
        ),
        CheckConstraint(
            "average_rating >= 0",
            name="ck_destination_popularity_average_rating_non_negative",
        ),
        CheckConstraint(
            "add_to_itinerary_count >= 0",
            name="ck_destination_popularity_add_to_itinerary_count_non_negative",
        ),
        CheckConstraint(
            "popularity_score >= 0",
            name="ck_destination_popularity_popularity_score_non_negative",
        ),
    )

    destination_id: Mapped[int] = mapped_column(
        ForeignKey("destinations.destination_id", ondelete="CASCADE"),
        primary_key=True,
    )
    view_count: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    save_count: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    rating_count: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    rating_sum: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    average_rating: Mapped[Decimal] = mapped_column(
        Numeric(3, 2),
        default=0,
        server_default=text("0"),
    )
    add_to_itinerary_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        server_default=text("0"),
    )
    popularity_score: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        default=0,
        server_default=text("0"),
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
