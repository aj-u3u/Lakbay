from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.expenses.schemas import (
    TripExpenseCreate,
    TripExpenseResponse,
    TripExpenseSummaryResponse,
    TripExpenseUpdate,
)
from app.features.expenses.service import ExpenseService
from app.features.users.models import User

router = APIRouter(prefix="/trips/{trip_id}/expenses", tags=["expenses"])


@router.get(
    "",
    response_model=list[TripExpenseResponse],
    summary="List trip expenses",
    description=(
        "Protected endpoint that lists expenses for a shared trip. Active trip "
        "members can view expenses. Voided expenses are hidden unless "
        "include_voided is true."
    ),
)
async def list_trip_expenses(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    include_voided: bool = False,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[TripExpenseResponse]:
    return await ExpenseService(session).list_expenses(
        user=current_user,
        trip_id=trip_id,
        include_voided=include_voided,
        limit=limit,
        offset=offset,
    )


@router.post(
    "",
    response_model=TripExpenseResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create trip expense",
    description=(
        "Protected endpoint that records an actual trip expense and creates "
        "equal split rows for the currently active trip members."
    ),
)
async def create_trip_expense(
    trip_id: int,
    data: TripExpenseCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripExpenseResponse:
    return await ExpenseService(session).create_expense(
        user=current_user,
        trip_id=trip_id,
        data=data,
    )


@router.get(
    "/summary",
    response_model=TripExpenseSummaryResponse,
    summary="Get trip expense summary",
    description=(
        "Protected endpoint that returns trip spending totals, category "
        "breakdowns, remaining budget, and per-member paid/share/net balances."
    ),
)
async def get_trip_expense_summary(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripExpenseSummaryResponse:
    return await ExpenseService(session).get_summary(
        user=current_user,
        trip_id=trip_id,
    )


@router.get(
    "/{expense_id}",
    response_model=TripExpenseResponse,
    summary="Get trip expense",
    description="Protected endpoint that returns one trip expense with split rows.",
)
async def get_trip_expense(
    trip_id: int,
    expense_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripExpenseResponse:
    return await ExpenseService(session).get_expense(
        user=current_user,
        trip_id=trip_id,
        expense_id=expense_id,
    )


@router.patch(
    "/{expense_id}",
    response_model=TripExpenseResponse,
    summary="Update trip expense",
    description=(
        "Protected endpoint that updates an active expense. If the amount "
        "changes, equal split rows are regenerated."
    ),
)
async def update_trip_expense(
    trip_id: int,
    expense_id: int,
    data: TripExpenseUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripExpenseResponse:
    return await ExpenseService(session).update_expense(
        user=current_user,
        trip_id=trip_id,
        expense_id=expense_id,
        data=data,
    )


@router.delete(
    "/{expense_id}",
    response_model=TripExpenseResponse,
    summary="Void trip expense",
    description=(
        "Protected soft delete. The expense remains in the database and is "
        "marked voided so it is excluded from active summaries."
    ),
)
async def void_trip_expense(
    trip_id: int,
    expense_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripExpenseResponse:
    return await ExpenseService(session).void_expense(
        user=current_user,
        trip_id=trip_id,
        expense_id=expense_id,
    )
