from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import require_admin
from app.db.session import get_db_session
from app.features.evaluation.schemas import EvaluationSummaryResponse
from app.features.evaluation.service import EvaluationService
from app.features.users.models import User


router = APIRouter(prefix="/evaluation", tags=["evaluation"])


@router.get(
    "/summary",
    response_model=EvaluationSummaryResponse,
    summary="Review Phase 14 evaluation measures",
    description=(
        "Admin-only aggregate of AI attempts, catalog engagement, and current "
        "destination readiness. No user-level records are returned."
    ),
)
async def evaluation_summary(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    _admin: Annotated[User, Depends(require_admin)],
    window_days: int = Query(default=30, ge=1, le=365),
) -> EvaluationSummaryResponse:
    return await EvaluationService(session).summary(window_days=window_days)
