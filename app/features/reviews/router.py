from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.reviews.schemas import (
    TripReviewCreate,
    TripReviewResponse,
    TripReviewSummaryResponse,
    TripReviewUpdate,
)
from app.features.reviews.service import ReviewService
from app.features.users.models import User


router = APIRouter(prefix="/trips/{trip_id}/reviews", tags=["reviews"])


@router.post(
    "",
    response_model=TripReviewResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create trip review",
    description=(
        "Protected endpoint that lets an active trip member submit feedback for "
        "a completed trip, optionally linked to one destination in that trip."
    ),
)
async def create_trip_review(
    trip_id: int,
    data: TripReviewCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripReviewResponse:
    return await ReviewService(session).create_review(
        user=current_user,
        trip_id=trip_id,
        data=data,
    )


@router.get(
    "",
    response_model=list[TripReviewResponse],
    summary="List trip reviews",
    description=(
        "Protected endpoint that lists active reviews for a completed trip. "
        "Use destination_id to focus on one trip destination."
    ),
)
async def list_trip_reviews(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    destination_id: int | None = Query(default=None, ge=1),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[TripReviewResponse]:
    return await ReviewService(session).list_reviews(
        user=current_user,
        trip_id=trip_id,
        destination_id=destination_id,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/summary",
    response_model=TripReviewSummaryResponse,
    summary="Get trip review summary",
    description=(
        "Protected endpoint that returns average feedback ratings for a trip. "
        "These values support later ISO/IEC 25010-style evaluation."
    ),
)
async def get_trip_review_summary(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripReviewSummaryResponse:
    return await ReviewService(session).get_summary(user=current_user, trip_id=trip_id)


@router.get(
    "/{review_id}",
    response_model=TripReviewResponse,
    summary="Get trip review",
    description="Protected endpoint that returns one active trip review.",
)
async def get_trip_review(
    trip_id: int,
    review_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripReviewResponse:
    return await ReviewService(session).get_review(
        user=current_user,
        trip_id=trip_id,
        review_id=review_id,
    )


@router.patch(
    "/{review_id}",
    response_model=TripReviewResponse,
    summary="Update trip review",
    description="Protected endpoint that lets the review author update feedback.",
)
async def update_trip_review(
    trip_id: int,
    review_id: int,
    data: TripReviewUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripReviewResponse:
    return await ReviewService(session).update_review(
        user=current_user,
        trip_id=trip_id,
        review_id=review_id,
        data=data,
    )


@router.delete(
    "/{review_id}",
    response_model=TripReviewResponse,
    summary="Delete trip review",
    description=(
        "Protected soft delete. The review remains in the database and is "
        "excluded from normal lists and review summaries."
    ),
)
async def delete_trip_review(
    trip_id: int,
    review_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripReviewResponse:
    return await ReviewService(session).delete_review(
        user=current_user,
        trip_id=trip_id,
        review_id=review_id,
    )
