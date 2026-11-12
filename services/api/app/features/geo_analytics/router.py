from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.geo_analytics.dependencies import GeoGroupLimiter, get_geo_group_limiter
from app.features.geo_analytics.schemas import (
    DestinationGroupsRequest,
    DestinationGroupsResponse,
)
from app.features.geo_analytics.service import GeoAnalyticsService
from app.features.routes.service import RouteService
from app.features.users.models import User
from app.integrations.osrm.client import OSRMClient, get_osrm_client

router = APIRouter(prefix="/geo-analytics", tags=["geo-analytics"])


@router.post("/destination-groups", response_model=DestinationGroupsResponse)
async def destination_groups(
    data: DestinationGroupsRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    osrm_client: Annotated[OSRMClient, Depends(get_osrm_client)],
    limiter: Annotated[GeoGroupLimiter, Depends(get_geo_group_limiter)],
) -> DestinationGroupsResponse:
    limiter.check(current_user.user_id)
    return await GeoAnalyticsService(session, RouteService(session, osrm_client)).group(
        data=data, user=current_user
    )
