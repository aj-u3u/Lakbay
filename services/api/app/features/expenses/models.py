from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class TripExpense(Base):
    __tablename__ = "trip_expenses"
    __table_args__ = (
        CheckConstraint(
            "category IN ('transportation', 'accommodation', 'meals', 'activities', 'other')",
            name="ck_trip_expenses_category",
        ),
        CheckConstraint(
            "status IN ('active', 'voided')",
            name="ck_trip_expenses_status",
        ),
        CheckConstraint(
            "split_method IN ('equal')",
            name="ck_trip_expenses_split_method",
        ),
        CheckConstraint("amount > 0", name="ck_trip_expenses_amount_positive"),
        UniqueConstraint(
            "trip_id",
            "trip_expense_id",
            name="uq_trip_expenses_trip_id_trip_expense_id",
        ),
        ForeignKeyConstraint(
            ["trip_id", "paid_by_trip_member_id"],
            ["trip_members.trip_id", "trip_members.trip_member_id"],
            name="fk_trip_expenses_trip_member_same_trip",
            ondelete="RESTRICT",
        ),
    )

    trip_expense_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    trip_id: Mapped[int] = mapped_column(
        ForeignKey("trips.trip_id", ondelete="CASCADE"),
        index=True,
    )
    paid_by_trip_member_id: Mapped[int] = mapped_column(
        ForeignKey("trip_members.trip_member_id", ondelete="RESTRICT"),
        index=True,
    )
    created_by_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="RESTRICT"),
        index=True,
    )
    category: Mapped[str] = mapped_column(String(50), index=True)
    title: Mapped[str] = mapped_column(String(255))
    description: Mapped[str | None] = mapped_column(Text)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    expense_date: Mapped[date] = mapped_column(Date, index=True)
    split_method: Mapped[str] = mapped_column(
        String(50),
        default="equal",
        server_default=text("'equal'"),
    )
    status: Mapped[str] = mapped_column(
        String(50),
        default="active",
        server_default=text("'active'"),
        index=True,
    )
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )

    paid_by_member: Mapped["TripMember"] = relationship(
        foreign_keys=[paid_by_trip_member_id],
    )
    created_by: Mapped["User"] = relationship(foreign_keys=[created_by_user_id])
    splits: Mapped[list["TripExpenseSplit"]] = relationship(
        back_populates="expense",
        cascade="all, delete-orphan",
        foreign_keys="TripExpenseSplit.trip_expense_id",
        passive_deletes=True,
    )


class TripExpenseSplit(Base):
    __tablename__ = "trip_expense_splits"
    __table_args__ = (
        UniqueConstraint(
            "trip_expense_id",
            "trip_member_id",
            name="uq_trip_expense_splits_expense_id_member_id",
        ),
        CheckConstraint(
            "share_amount >= 0",
            name="ck_trip_expense_splits_share_amount_non_negative",
        ),
        ForeignKeyConstraint(
            ["trip_id", "trip_expense_id"],
            ["trip_expenses.trip_id", "trip_expenses.trip_expense_id"],
            name="fk_trip_expense_splits_expense_same_trip",
            ondelete="CASCADE",
        ),
        ForeignKeyConstraint(
            ["trip_id", "trip_member_id"],
            ["trip_members.trip_id", "trip_members.trip_member_id"],
            name="fk_trip_expense_splits_member_same_trip",
            ondelete="RESTRICT",
        ),
    )

    trip_expense_split_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    trip_id: Mapped[int] = mapped_column(index=True)
    trip_expense_id: Mapped[int] = mapped_column(
        ForeignKey("trip_expenses.trip_expense_id", ondelete="CASCADE"),
        index=True,
    )
    trip_member_id: Mapped[int] = mapped_column(
        ForeignKey("trip_members.trip_member_id", ondelete="RESTRICT"),
        index=True,
    )
    share_amount: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    expense: Mapped["TripExpense"] = relationship(
        back_populates="splits",
        foreign_keys=[trip_expense_id],
    )
    member: Mapped["TripMember"] = relationship(foreign_keys=[trip_member_id])
