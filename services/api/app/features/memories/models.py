from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class TripMemory(Base):
    __tablename__ = "trip_memories"
    __table_args__ = (
        CheckConstraint(
            "status IN ('active', 'deleted')",
            name="ck_trip_memories_status",
        ),
        CheckConstraint("like_count >= 0", name="ck_trip_memories_like_count_non_negative"),
        CheckConstraint(
            "comment_count >= 0",
            name="ck_trip_memories_comment_count_non_negative",
        ),
        ForeignKeyConstraint(
            ["trip_id", "uploaded_by_trip_member_id"],
            ["trip_members.trip_id", "trip_members.trip_member_id"],
            name="fk_trip_memories_uploader_same_trip",
            ondelete="RESTRICT",
        ),
    )

    trip_memory_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    trip_id: Mapped[int] = mapped_column(
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        index=True,
    )
    uploaded_by_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="RESTRICT"),
        index=True,
    )
    uploaded_by_trip_member_id: Mapped[int] = mapped_column(index=True)
    destination_id: Mapped[int | None] = mapped_column(
        ForeignKey("destinations.destination_id", ondelete="SET NULL"),
        index=True,
    )
    image_url: Mapped[str] = mapped_column(Text)
    cloudinary_public_id: Mapped[str | None] = mapped_column(String(500), index=True)
    caption: Mapped[str | None] = mapped_column(Text)
    location_tag: Mapped[str | None] = mapped_column(String(255))
    taken_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(
        String(50),
        default="active",
        server_default=text("'active'"),
        index=True,
    )
    like_count: Mapped[int] = mapped_column(Integer, default=0, server_default=text("0"))
    comment_count: Mapped[int] = mapped_column(
        Integer,
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

    uploaded_by_member: Mapped["TripMember"] = relationship(
        foreign_keys=[uploaded_by_trip_member_id],
    )
    uploaded_by_user: Mapped["User"] = relationship(foreign_keys=[uploaded_by_user_id])
    destination: Mapped["Destination | None"] = relationship()
