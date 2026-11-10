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
    TopPlacesRequest,
    TopPlacesResponse,
)
from app.features.recommendations.service import RecommendationService
from app.features.routes.dependencies import enforce_route_request_limit
from app.features.users.models import User
from app.integrations.osrm.client import OSRMClient, get_osrm_client


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


@router.post(
    "/top-places",
    response_model=TopPlacesResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Rank the personalized Top 5 places",
    description=(
        "Ranks active destinations with a weighted scoring model (Simple "
        "Additive Weighting) using interests, start point, travel mode, budget, "
        "party, and trip length. Each place returns its 0-100 score, factor "
        "breakdown, reasons, and how travel time and cost were measured. Places "
        "with a verified road route to a visitor entrance come first. Saves the "
        "preference signal like POST /recommendations."
    ),
    dependencies=[Depends(enforce_route_request_limit)],
)
async def rank_top_places(
    data: TopPlacesRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    osrm_client: Annotated[OSRMClient, Depends(get_osrm_client)],
) -> TopPlacesResponse:
    return await RecommendationService(session).rank_top_places(
        data=data,
        osrm_client=osrm_client,
        user=current_user,
        save_preference=True,
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
