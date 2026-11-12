from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.routes.dependencies import enforce_route_request_limit
from app.features.routes.schemas import (
    RouteOptimizeRequest,
    RoutePreviewRequest,
    RouteSummaryResponse,
)
from app.features.routes.service import RouteService
from app.features.users.models import User
from app.integrations.google_routes.client import (
    GoogleRoutesClient,
    get_google_routes_client,
)
from app.integrations.osrm.client import OSRMClient, get_osrm_client

router = APIRouter(prefix="/routes", tags=["routes"])


@router.post(
    "/preview",
    response_model=RouteSummaryResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(enforce_route_request_limit)],
    summary="Preview a route",
    description=(
        "Protected endpoint that keeps the selected destination order and returns "
        "a route distance, duration, stops, and legs. OSRM is used for driving "
        "and walking when configured; otherwise the response falls back to a "
        "Haversine estimate."
    ),
)
async def preview_route(
    data: RoutePreviewRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    osrm_client: Annotated[OSRMClient, Depends(get_osrm_client)],
    google_routes_client: Annotated[
        GoogleRoutesClient,
        Depends(get_google_routes_client),
    ],
) -> RouteSummaryResponse:
    return await RouteService(
        session,
        osrm_client,
        google_routes_client,
    ).preview_route(data)


@router.post(
    "/optimize",
    response_model=RouteSummaryResponse,
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(enforce_route_request_limit)],
    summary="Optimize destination order",
    description=(
        "Protected endpoint that suggests an efficient order for selected "
        "destinations and returns the ordered route summary. OSRM Trip is used "
        "when configured for driving or walking; public transport and OSRM "
        "failures use estimated fallback ordering."
    ),
)
async def optimize_route(
    data: RouteOptimizeRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    osrm_client: Annotated[OSRMClient, Depends(get_osrm_client)],
    google_routes_client: Annotated[
        GoogleRoutesClient,
        Depends(get_google_routes_client),
    ],
) -> RouteSummaryResponse:
    return await RouteService(
        session,
        osrm_client,
        google_routes_client,
    ).optimize_route(data)
