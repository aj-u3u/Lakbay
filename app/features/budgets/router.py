from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.budgets.schemas import (
    BudgetEstimateRequest,
    BudgetEstimateResponse,
)
from app.features.budgets.service import BudgetService
from app.features.users.models import User

router = APIRouter(prefix="/budgets", tags=["budgets"])


@router.post(
    "/estimate",
    response_model=BudgetEstimateResponse,
    status_code=status.HTTP_200_OK,
    summary="Estimate trip budget",
    description=(
        "Protected endpoint that checks selected destinations, accommodations, "
        "transportation options, meal estimates, and miscellaneous costs against "
        "a user's planned budget."
    ),
)
async def estimate_budget(
    data: BudgetEstimateRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> BudgetEstimateResponse:
    return await BudgetService(session).estimate_budget(data)
