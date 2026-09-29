from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.expenses.models import TripExpense, TripExpenseSplit
from app.features.trips.models import Trip, TripMember


class ExpenseRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_trip_with_members(self, *, trip_id: int) -> Trip | None:
        result = await self.session.execute(
            select(Trip)
            .where(Trip.trip_id == trip_id)
            .options(selectinload(Trip.members).selectinload(TripMember.user))
        )

        return result.scalar_one_or_none()

    async def get_trip_member(
        self,
        *,
        trip_id: int,
        trip_member_id: int,
    ) -> TripMember | None:
        result = await self.session.execute(
            select(TripMember)
            .where(
                TripMember.trip_id == trip_id,
                TripMember.trip_member_id == trip_member_id,
            )
            .options(selectinload(TripMember.user))
        )

        return result.scalar_one_or_none()

    async def list_expenses(
        self,
        *,
        trip_id: int,
        include_voided: bool,
        limit: int,
        offset: int,
    ) -> list[TripExpense]:
        statement = (
            select(TripExpense)
            .where(TripExpense.trip_id == trip_id)
            .options(*_expense_options())
            .order_by(TripExpense.expense_date.desc(), TripExpense.trip_expense_id.desc())
            .offset(offset)
            .limit(limit)
        )

        if not include_voided:
            statement = statement.where(TripExpense.status == "active")

        result = await self.session.execute(statement)

        return list(result.scalars().all())

    async def list_active_expenses_for_summary(self, *, trip_id: int) -> list[TripExpense]:
        result = await self.session.execute(
            select(TripExpense)
            .where(
                TripExpense.trip_id == trip_id,
                TripExpense.status == "active",
            )
            .options(*_expense_options())
            .order_by(TripExpense.trip_expense_id.asc())
        )

        return list(result.scalars().all())

    async def get_expense(
        self,
        *,
        trip_id: int,
        expense_id: int,
    ) -> TripExpense | None:
        result = await self.session.execute(
            select(TripExpense)
            .where(
                TripExpense.trip_id == trip_id,
                TripExpense.trip_expense_id == expense_id,
            )
            .options(*_expense_options())
        )

        return result.scalar_one_or_none()

    async def add_expense(self, expense: TripExpense) -> TripExpense:
        self.session.add(expense)
        await self.session.flush()

        return expense

    async def replace_splits(
        self,
        *,
        expense: TripExpense,
        splits: list[TripExpenseSplit],
    ) -> None:
        if expense.trip_expense_id is not None:
            await self.session.execute(
                delete(TripExpenseSplit).where(
                    TripExpenseSplit.trip_expense_id == expense.trip_expense_id,
                )
            )

        expense.splits = splits
        await self.session.flush()


def _expense_options():
    return (
        selectinload(TripExpense.paid_by_member).selectinload(TripMember.user),
        selectinload(TripExpense.splits).selectinload(TripExpenseSplit.member).selectinload(TripMember.user),
    )
