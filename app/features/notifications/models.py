from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Notification(Base):
    __tablename__ = "notifications"
    __table_args__ = (
        CheckConstraint(
            (
                "event_type IN ("
                "'trip_member_added', "
                "'task_assigned', "
                "'task_updated', "
                "'expense_created', "
                "'expense_updated', "
                "'expense_voided', "
                "'trip_updated', "
                "'trip_route_updated'"
                ")"
            ),
            name="ck_notifications_event_type",
        ),
        CheckConstraint(
            (
                "entity_type IS NULL OR entity_type IN ("
                "'trip', "
                "'trip_member', "
                "'trip_task', "
                "'trip_expense', "
                "'trip_route'"
                ")"
            ),
            name="ck_notifications_entity_type",
        ),
        CheckConstraint(
            "status IN ('active', 'deleted')",
            name="ck_notifications_status",
        ),
        CheckConstraint(
            (
                "(entity_type IS NULL AND entity_id IS NULL) OR "
                "(entity_type IS NOT NULL AND entity_id IS NOT NULL)"
            ),
            name="ck_notifications_entity_pair",
        ),
        Index(
            "ix_notifications_recipient_status_created",
            "recipient_user_id",
            "status",
            "created_at",
        ),
    )

    notification_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    recipient_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        index=True,
    )
    actor_user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.user_id", ondelete="SET NULL"),
        index=True,
    )
    trip_id: Mapped[int | None] = mapped_column(
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        index=True,
    )
    event_type: Mapped[str] = mapped_column(String(100), index=True)
    title: Mapped[str] = mapped_column(String(255))
    message: Mapped[str] = mapped_column(Text)
    entity_type: Mapped[str | None] = mapped_column(String(100), index=True)
    entity_id: Mapped[int | None] = mapped_column(Integer, index=True)
    metadata_: Mapped[dict] = mapped_column(
        "metadata",
        JSON,
        default=dict,
        server_default=text("'{}'"),
    )
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    status: Mapped[str] = mapped_column(
        String(50),
        default="active",
        server_default=text("'active'"),
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        index=True,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    recipient: Mapped["User"] = relationship(foreign_keys=[recipient_user_id])
    actor: Mapped["User | None"] = relationship(foreign_keys=[actor_user_id])
    trip: Mapped["Trip | None"] = relationship()
