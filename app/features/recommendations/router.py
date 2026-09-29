from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.recommendations.schemas import (
    DestinationInteractionCreate,
    DestinationInteractionResponse,
    DestinationPopularityResponse,
    PreferenceSignalResponse,
    RecommendationRequest,
    RecommendationResponse,
)
from app.features.recommendations.service import RecommendationService
from app.features.users.models import User


router = APIRouter(prefix="/recommendations", tags=["recommendations"])
destination_router = APIRouter(
    prefix="/destinations/{destination_id}",
    tags=["recommendations"],
)


@router.post(
    "",
    response_model=RecommendationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create destination recommendations",
    description=(
        "Protected endpoint that saves the user's travel preferences, scores "
        "active destinations using deterministic rules, and returns ranked, "
        "explainable recommendations."
    ),
)
async def create_recommendations(
    data: RecommendationRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> RecommendationResponse:
    return await RecommendationService(session).recommend_destinations(
        user=current_user,
        data=data,
    )


@router.get(
    "/preferences/latest",
    response_model=PreferenceSignalResponse,
    summary="Get latest recommendation preferences",
    description=(
        "Returns the most recent saved preference signal for the authenticated "
        "user."
    ),
)
async def get_latest_preference(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> PreferenceSignalResponse:
    return await RecommendationService(session).get_latest_preference(
        user=current_user,
    )


@destination_router.post(
    "/interactions",
    response_model=DestinationInteractionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Record destination interaction",
    description=(
        "Protected endpoint for recording a user's destination action: view, "
        "save, rate, or add_to_itinerary. It also updates destination "
        "popularity counters."
    ),
)
async def create_destination_interaction(
    destination_id: int,
    data: DestinationInteractionCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> DestinationInteractionResponse:
    return await RecommendationService(session).create_interaction(
        user=current_user,
        destination_id=destination_id,
        data=data,
    )


@destination_router.get(
    "/popularity",
    response_model=DestinationPopularityResponse,
    summary="Get destination popularity",
    description=(
        "Returns aggregate interaction counters and the deterministic "
        "popularity score for one active destination."
    ),
)
async def get_destination_popularity(
    destination_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> DestinationPopularityResponse:
    return await RecommendationService(session).get_popularity(
        destination_id=destination_id,
    )
