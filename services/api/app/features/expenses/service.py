from datetime import UTC, date, datetime
from decimal import Decimal, ROUND_HALF_UP

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.expenses.models import TripExpense, TripExpenseSplit
from app.features.expenses.repository import ExpenseRepository
from app.features.expenses.schemas import (
    ExpenseCategory,
    TripExpenseCategoryBreakdown,
    TripExpenseCreate,
    TripExpenseMemberBalance,
    TripExpenseResponse,
    TripExpenseSplitResponse,
    TripExpenseSummaryResponse,
    TripExpenseUpdate,
)
from app.features.notifications.service import NotificationService
from app.features.trips.models import Trip, TripMember
from app.features.users.models import User


class ExpenseService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.expenses = ExpenseRepository(session)
        self.notifications = NotificationService(session)

    async def list_expenses(
        self,
        *,
        user: User,
        trip_id: int,
        include_voided: bool,
        limit: int,
        offset: int,
    ) -> list[TripExpenseResponse]:
        await self._require_active_member(user=user, trip_id=trip_id)
        expenses = await self.expenses.list_expenses(
            trip_id=trip_id,
            include_voided=include_voided,
            limit=limit,
            offset=offset,
        )

        return [_expense_response(expense) for expense in expenses]

    async def get_expense(
        self,
        *,
        user: User,
        trip_id: int,
        expense_id: int,
    ) -> TripExpenseResponse:
        await self._require_active_member(user=user, trip_id=trip_id)
        expense = await self._require_expense(trip_id=trip_id, expense_id=expense_id)

        return _expense_response(expense)

    async def create_expense(
        self,
        *,
        user: User,
        trip_id: int,
        data: TripExpenseCreate,
    ) -> TripExpenseResponse:
        trip, current_member = await self._require_active_member(
            user=user,
            trip_id=trip_id,
        )
        self._require_trip_mutable(trip)
        paid_by_member = await self._require_active_member_by_id(
            trip_id=trip_id,
            member_id=data.paid_by_trip_member_id,
        )
        self._require_payer_permission(
            current_member=current_member,
            paid_by_member=paid_by_member,
        )

        active_members = _active_members(trip)
        split_amounts = _equal_split_amounts(data.amount, active_members)
        expense = TripExpense(
            trip_id=trip_id,
            paid_by_trip_member_id=paid_by_member.trip_member_id,
            created_by_user_id=user.user_id,
            category=data.category,
            title=data.title,
            description=data.description,
            amount=data.amount,
            expense_date=data.expense_date or datetime.now(UTC).date(),
            split_method=data.split_method,
            status="active",
            notes=data.notes,
            splits=[
                TripExpenseSplit(
                    trip_id=trip_id,
                    trip_member_id=member.trip_member_id,
                    share_amount=share_amount,
                )
                for member, share_amount in zip(active_members, split_amounts, strict=True)
            ],
        )

        await self.expenses.add_expense(expense)
        await self.notifications.notify_expense_created(
            actor=user,
            trip=trip,
            expense=expense,
        )
        await self.session.commit()

        created_expense = await self._require_expense(
            trip_id=trip_id,
            expense_id=expense.trip_expense_id,
        )

        return _expense_response(created_expense)

    async def update_expense(
        self,
        *,
        user: User,
        trip_id: int,
        expense_id: int,
        data: TripExpenseUpdate,
    ) -> TripExpenseResponse:
        trip, current_member = await self._require_active_member(
            user=user,
            trip_id=trip_id,
        )
        self._require_trip_mutable(trip)
        expense = await self._require_expense(trip_id=trip_id, expense_id=expense_id)
        self._require_expense_active(expense)
        self._require_expense_editor(user=user, current_member=current_member, expense=expense)
        values = data.model_dump(exclude_unset=True)

        if not values:
            raise LakbayAPIError(
                "At least one expense field must be provided.",
                code="empty_expense_update",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if "paid_by_trip_member_id" in values:
            paid_by_member = await self._require_active_member_by_id(
                trip_id=trip_id,
                member_id=values["paid_by_trip_member_id"],
            )
            self._require_payer_permission(
                current_member=current_member,
                paid_by_member=paid_by_member,
            )

        for field, value in values.items():
            setattr(expense, field, value)

        if "amount" in values:
            split_members = _expense_split_members(expense) or _active_members(trip)
            split_amounts = _equal_split_amounts(expense.amount, split_members)
            await self.expenses.replace_splits(
                expense=expense,
                splits=[
                    TripExpenseSplit(
                        trip_id=trip_id,
                        trip_member_id=member.trip_member_id,
                        share_amount=share_amount,
                    )
                    for member, share_amount in zip(
                        split_members,
                        split_amounts,
                        strict=True,
                    )
                ],
            )

        await self.notifications.notify_expense_updated(
            actor=user,
            trip=trip,
            expense=expense,
            changed_fields=list(values.keys()),
        )
        await self.session.commit()
        updated_expense = await self._require_expense(
            trip_id=trip_id,
            expense_id=expense_id,
        )

        return _expense_response(updated_expense)

    async def void_expense(
        self,
        *,
        user: User,
        trip_id: int,
        expense_id: int,
    ) -> TripExpenseResponse:
        trip, current_member = await self._require_active_member(
            user=user,
            trip_id=trip_id,
        )
        self._require_trip_mutable(trip)
        expense = await self._require_expense(trip_id=trip_id, expense_id=expense_id)
        self._require_expense_active(expense)
        self._require_expense_editor(user=user, current_member=current_member, expense=expense)

        expense.status = "voided"
        await self.notifications.notify_expense_voided(
            actor=user,
            trip=trip,
            expense=expense,
        )
        await self.session.commit()

        voided_expense = await self._require_expense(
            trip_id=trip_id,
            expense_id=expense_id,
        )

        return _expense_response(voided_expense)

    async def get_summary(
        self,
        *,
        user: User,
        trip_id: int,
    ) -> TripExpenseSummaryResponse:
        trip, _ = await self._require_active_member(user=user, trip_id=trip_id)
        expenses = await self.expenses.list_active_expenses_for_summary(trip_id=trip_id)
        summary_members_by_id = {
            member.trip_member_id: member
            for member in _active_members(trip)
        }

        for expense in expenses:
            summary_members_by_id.setdefault(
                expense.paid_by_member.trip_member_id,
                expense.paid_by_member,
            )
            for split in expense.splits:
                summary_members_by_id.setdefault(split.trip_member_id, split.member)

        summary_members = sorted(
            summary_members_by_id.values(),
            key=lambda member: member.trip_member_id,
        )
        total_spent = _money(sum((expense.amount for expense in expenses), Decimal("0.00")))
        category_totals: dict[ExpenseCategory, Decimal] = {
            "transportation": Decimal("0.00"),
            "accommodation": Decimal("0.00"),
            "meals": Decimal("0.00"),
            "activities": Decimal("0.00"),
            "other": Decimal("0.00"),
        }
        paid_totals = {
            member.trip_member_id: Decimal("0.00")
            for member in summary_members
        }
        share_totals = {
            member.trip_member_id: Decimal("0.00")
            for member in summary_members
        }

        for expense in expenses:
            category_totals[expense.category] = _money(
                category_totals[expense.category] + expense.amount,
            )
            if expense.paid_by_trip_member_id in paid_totals:
                paid_totals[expense.paid_by_trip_member_id] = _money(
                    paid_totals[expense.paid_by_trip_member_id] + expense.amount,
                )

            for split in expense.splits:
                if split.trip_member_id in share_totals:
                    share_totals[split.trip_member_id] = _money(
                        share_totals[split.trip_member_id] + split.share_amount,
                    )

        remaining_budget = _money(trip.total_budget - total_spent)
        over_budget_amount = _money(max(total_spent - trip.total_budget, Decimal("0.00")))

        return TripExpenseSummaryResponse(
            trip_id=trip.trip_id,
            total_budget=trip.total_budget,
            total_spent=total_spent,
            remaining_budget=remaining_budget,
            over_budget_amount=over_budget_amount,
            is_over_budget=total_spent > trip.total_budget,
            category_breakdown=[
                TripExpenseCategoryBreakdown(category=category, total=total)
                for category, total in category_totals.items()
                if total > 0
            ],
            member_balances=[
                TripExpenseMemberBalance(
                    trip_member_id=member.trip_member_id,
                    user_id=member.user_id,
                    full_name=member.user.full_name,
                    email=member.user.email,
                    paid_total=_money(paid_totals[member.trip_member_id]),
                    share_total=_money(share_totals[member.trip_member_id]),
                    net_balance=_money(
                        paid_totals[member.trip_member_id]
                        - share_totals[member.trip_member_id],
                    ),
                )
                for member in summary_members
            ],
        )

    async def _require_active_member(
        self,
        *,
        user: User,
        trip_id: int,
    ) -> tuple[Trip, TripMember]:
        trip = await self.expenses.get_trip_with_members(trip_id=trip_id)

        if trip is None:
            raise LakbayAPIError(
                "Trip was not found.",
                code="trip_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        member = _active_member_for_user(trip, user.user_id)

        if member is None:
            raise LakbayAPIError(
                "Trip was not found.",
                code="trip_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return trip, member

    async def _require_active_member_by_id(
        self,
        *,
        trip_id: int,
        member_id: int,
    ) -> TripMember:
        member = await self.expenses.get_trip_member(
            trip_id=trip_id,
            trip_member_id=member_id,
        )

        if member is None or member.status != "active":
            raise LakbayAPIError(
                "Trip member was not found.",
                code="trip_member_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return member

    async def _require_expense(self, *, trip_id: int, expense_id: int) -> TripExpense:
        expense = await self.expenses.get_expense(
            trip_id=trip_id,
            expense_id=expense_id,
        )

        if expense is None:
            raise LakbayAPIError(
                "Trip expense was not found.",
                code="trip_expense_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return expense

    def _require_trip_mutable(self, trip: Trip) -> None:
        if trip.status == "archived":
            raise LakbayAPIError(
                "Archived trips are read-only for expenses.",
                code="trip_archived_read_only",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

    def _require_payer_permission(
        self,
        *,
        current_member: TripMember,
        paid_by_member: TripMember,
    ) -> None:
        if current_member.role in {"owner", "organizer"}:
            return

        if current_member.trip_member_id == paid_by_member.trip_member_id:
            return

        raise LakbayAPIError(
            "Members can only create expenses paid by themselves.",
            code="expense_payer_permission_denied",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    def _require_expense_editor(
        self,
        *,
        user: User,
        current_member: TripMember,
        expense: TripExpense,
    ) -> None:
        if current_member.role in {"owner", "organizer"}:
            return

        if expense.created_by_user_id == user.user_id:
            return

        raise LakbayAPIError(
            "You do not have permission to edit this expense.",
            code="expense_permission_denied",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    def _require_expense_active(self, expense: TripExpense) -> None:
        if expense.status == "active":
            return

        raise LakbayAPIError(
            "Voided expenses cannot be changed.",
            code="trip_expense_voided",
            status_code=status.HTTP_400_BAD_REQUEST,
        )


def _expense_response(expense: TripExpense) -> TripExpenseResponse:
    return TripExpenseResponse(
        trip_expense_id=expense.trip_expense_id,
        trip_id=expense.trip_id,
        paid_by_trip_member_id=expense.paid_by_trip_member_id,
        paid_by_user_id=expense.paid_by_member.user_id,
        paid_by_full_name=expense.paid_by_member.user.full_name,
        paid_by_email=expense.paid_by_member.user.email,
        created_by_user_id=expense.created_by_user_id,
        category=expense.category,
        title=expense.title,
        description=expense.description,
        amount=expense.amount,
        expense_date=expense.expense_date,
        split_method=expense.split_method,
        status=expense.status,
        notes=expense.notes,
        splits=[
            TripExpenseSplitResponse(
                trip_expense_split_id=split.trip_expense_split_id,
                trip_expense_id=split.trip_expense_id,
                trip_member_id=split.trip_member_id,
                user_id=split.member.user_id,
                full_name=split.member.user.full_name,
                email=split.member.user.email,
                share_amount=split.share_amount,
                created_at=split.created_at,
            )
            for split in sorted(
                expense.splits,
                key=lambda split: split.trip_member_id,
            )
        ],
        created_at=expense.created_at,
        updated_at=expense.updated_at,
    )


def _active_members(trip: Trip) -> list[TripMember]:
    return sorted(
        [member for member in trip.members if member.status == "active"],
        key=lambda member: member.trip_member_id,
    )


def _expense_split_members(expense: TripExpense) -> list[TripMember]:
    return [
        split.member
        for split in sorted(
            expense.splits,
            key=lambda split: split.trip_member_id,
        )
    ]


def _active_member_for_user(trip: Trip, user_id: int) -> TripMember | None:
    return next(
        (
            member
            for member in _active_members(trip)
            if member.user_id == user_id
        ),
        None,
    )


def _equal_split_amounts(
    amount: Decimal,
    members: list[TripMember],
) -> list[Decimal]:
    if not members:
        raise LakbayAPIError(
            "At least one active trip member is required for expense splits.",
            code="trip_has_no_active_members",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    total_cents = int(_money(amount) * 100)
    base_cents = total_cents // len(members)
    remainder = total_cents % len(members)

    return [
        _cents_to_money(base_cents + (1 if index < remainder else 0))
        for index, _member in enumerate(members)
    ]


def _cents_to_money(cents: int) -> Decimal:
    return _money(Decimal(cents) / Decimal(100))


def _money(value: Decimal) -> Decimal:
    return Decimal(value).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
