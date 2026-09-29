from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Transportation(Base):
    __tablename__ = "transportations"
    __table_args__ = (
        CheckConstraint("price >= 0", name="ck_transportations_price_non_negative"),
        CheckConstraint(
            "duration_minutes IS NULL OR duration_minutes >= 0",
            name="ck_transportations_duration_minutes_non_negative",
        ),
    )

    transportation_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    destination_id: Mapped[int] = mapped_column(
        ForeignKey("destinations.destination_id", ondelete="CASCADE"),
        index=True,
    )
    vehicle_type: Mapped[str] = mapped_column(String(100))
    transport_mode: Mapped[str] = mapped_column(String(100), index=True)
    route_from: Mapped[str] = mapped_column(String(255))
    route_to: Mapped[str] = mapped_column(String(255))
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    duration_minutes: Mapped[int | None] = mapped_column()
    duration_text: Mapped[str | None] = mapped_column(String(100))
    notes: Mapped[str | None] = mapped_column(Text)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    destination: Mapped["Destination"] = relationship(back_populates="transportations")
