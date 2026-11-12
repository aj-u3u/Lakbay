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


class Accommodation(Base):
    __tablename__ = "accommodations"
    __table_args__ = (
        CheckConstraint("price >= 0", name="ck_accommodations_price_non_negative"),
        CheckConstraint("capacity >= 1", name="ck_accommodations_capacity_positive"),
        CheckConstraint("currency = 'PHP'", name="ck_accommodations_currency_php"),
        CheckConstraint(
            "charging_unit IS NULL OR charging_unit IN "
            "('per_room_per_night', 'per_room_per_stay')",
            name="ck_accommodations_charging_unit",
        ),
    )

    accommodation_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    destination_id: Mapped[int] = mapped_column(
        ForeignKey("destinations.destination_id", ondelete="CASCADE"),
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255))
    room_type: Mapped[str] = mapped_column(String(255))
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    currency: Mapped[str] = mapped_column(String(3), server_default="PHP")
    charging_unit: Mapped[str | None] = mapped_column(String(32))
    capacity: Mapped[int] = mapped_column(default=2)
    description: Mapped[str | None] = mapped_column(Text)
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

    destination: Mapped["Destination"] = relationship(back_populates="accommodations")
