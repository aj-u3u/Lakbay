from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


RATING_FIELDS = (
    "functional_suitability_rating",
    "information_accuracy_rating",
    "performance_rating",
    "interaction_rating",
    "reliability_rating",
    "sharing_clarity_rating",
)


class AppAssessment(Base):
    __tablename__ = "app_assessments"
    __table_args__ = (
        UniqueConstraint("trip_id", "user_id", name="uq_app_assessments_trip_user"),
        CheckConstraint("question_version >= 1", name="ck_app_assessments_question_version_positive"),
        CheckConstraint(
            " OR ".join(f"{field} IS NOT NULL" for field in RATING_FIELDS),
            name="ck_app_assessments_one_rating_required",
        ),
        ForeignKeyConstraint(
            ["trip_id", "user_id"],
            ["trip_members.trip_id", "trip_members.user_id"],
            name="fk_app_assessments_member_same_trip",
            ondelete="RESTRICT",
        ),
        *(
            CheckConstraint(
                f"{field} IS NULL OR {field} BETWEEN 1 AND 5",
                name=f"ck_app_assessments_{field}_range",
            )
            for field in RATING_FIELDS
        ),
    )

    app_assessment_id: Mapped[int] = mapped_column(primary_key=True)
    trip_id: Mapped[int] = mapped_column(ForeignKey("trips.trip_id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.user_id", ondelete="CASCADE"), index=True)
    question_version: Mapped[int] = mapped_column(Integer, default=1)
    functional_suitability_rating: Mapped[int | None] = mapped_column(Integer)
    information_accuracy_rating: Mapped[int | None] = mapped_column(Integer)
    performance_rating: Mapped[int | None] = mapped_column(Integer)
    interaction_rating: Mapped[int | None] = mapped_column(Integer)
    reliability_rating: Mapped[int | None] = mapped_column(Integer)
    sharing_clarity_rating: Mapped[int | None] = mapped_column(Integer)
    comment: Mapped[str | None] = mapped_column(Text)
    app_version: Mapped[str | None] = mapped_column(String(32))
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)
