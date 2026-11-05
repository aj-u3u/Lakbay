from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import require_admin
from app.db.session import get_db_session
from app.features.destinations.candidate_schemas import (
    CandidateReject,
    CandidateCreate,
    CandidateResponse,
    CandidateStatus,
    CandidateUpdate,
)
from app.features.destinations.candidate_service import CandidateService
from app.features.users.models import User


router = APIRouter(prefix="/admin/destination-candidates", tags=["destination candidates"])


@router.post("", response_model=CandidateResponse, status_code=status.HTTP_201_CREATED)
async def stage_candidate(
    data: CandidateCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> CandidateResponse:
    return await CandidateService(session).create(data)


@router.get("", response_model=list[CandidateResponse])
async def list_candidates(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
    review_status: CandidateStatus | None = None,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[CandidateResponse]:
    return await CandidateService(session).list(
        review_status=review_status, limit=limit, offset=offset
    )


@router.get("/{candidate_id}", response_model=CandidateResponse)
async def get_candidate(
    candidate_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> CandidateResponse:
    return await CandidateService(session).get(candidate_id)


@router.patch("/{candidate_id}", response_model=CandidateResponse)
async def update_candidate(
    candidate_id: int,
    data: CandidateUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> CandidateResponse:
    return await CandidateService(session).update(candidate_id, data)


@router.post("/{candidate_id}/reject", response_model=CandidateResponse)
async def reject_candidate(
    candidate_id: int,
    data: CandidateReject,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> CandidateResponse:
    return await CandidateService(session).reject(candidate_id, data.reason)


@router.post("/{candidate_id}/publish", response_model=CandidateResponse)
async def publish_candidate(
    candidate_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> CandidateResponse:
    return await CandidateService(session).publish(candidate_id)
