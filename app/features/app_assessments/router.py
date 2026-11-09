from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user, require_admin
from app.db.session import get_db_session
from app.features.app_assessments.schemas import (
    AdminAppAssessmentListResponse,
    AdminAppAssessmentSummaryResponse,
    AppAssessmentCreate,
    AppAssessmentResponse,
    MyAppAssessmentResponse,
)
from app.features.app_assessments.service import AppAssessmentService
from app.features.users.models import User


router = APIRouter(prefix="/trips/{trip_id}/app-assessment", tags=["app-assessments"])
admin_router = APIRouter(prefix="/evaluation/app-assessments", tags=["evaluation"])


@router.get("/me", response_model=MyAppAssessmentResponse)
async def get_my_app_assessment(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> MyAppAssessmentResponse:
    return await AppAssessmentService(session).get_mine(user=current_user, trip_id=trip_id)


@router.post("", response_model=AppAssessmentResponse, status_code=status.HTTP_201_CREATED)
async def create_app_assessment(
    trip_id: int,
    data: AppAssessmentCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> AppAssessmentResponse:
    return await AppAssessmentService(session).create(
        user=current_user, trip_id=trip_id, data=data
    )


@admin_router.get("/summary", response_model=AdminAppAssessmentSummaryResponse)
async def app_assessment_summary(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    _admin: Annotated[User, Depends(require_admin)],
    window_days: int = Query(default=30, ge=1, le=365),
) -> AdminAppAssessmentSummaryResponse:
    return await AppAssessmentService(session).summary_for_admin(window_days=window_days)


@admin_router.get("", response_model=AdminAppAssessmentListResponse)
async def list_app_assessments(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    _admin: Annotated[User, Depends(require_admin)],
    window_days: int = Query(default=30, ge=1, le=365),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> AdminAppAssessmentListResponse:
    return await AppAssessmentService(session).list_for_admin(
        window_days=window_days, limit=limit, offset=offset
    )
