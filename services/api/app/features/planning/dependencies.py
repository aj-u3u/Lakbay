"""Optional routing dependencies and a bounded per-user development limiter."""

from functools import lru_cache
from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.dependencies import get_current_user
from app.core.provider_usage import PerUserRequestLimiter
from app.db.session import get_db_session
from app.features.planning.schemas import PlanningFeedbackRequest
from app.features.routes.service import RouteService
from app.features.users.models import User
from app.integrations.osrm.client import get_osrm_client


class PlanningRouteLimiter(PerUserRequestLimiter):
    message = "Too many planning route requests. Try again shortly."
    code = "planning_route_rate_limit_exceeded"


@lru_cache(maxsize=8)
def _route_limiter(limit: int) -> PlanningRouteLimiter:
    return PlanningRouteLimiter(limit=limit)


def get_planning_route_limiter() -> PlanningRouteLimiter:
    return _route_limiter(get_settings().planning_route_requests_per_minute)


def enforce_planning_route_limit(
    data: PlanningFeedbackRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    limiter: Annotated[PlanningRouteLimiter, Depends(get_planning_route_limiter)],
) -> None:
    if data.state.route_preferences is not None:
        limiter.check(current_user.user_id)


def get_planning_route_service(
    data: PlanningFeedbackRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    route_limit: Annotated[None, Depends(enforce_planning_route_limit)],
) -> RouteService | None:
    # Construct a provider only when routing was explicitly requested.
    if data.state.route_preferences is None:
        return None
    return RouteService(session, get_osrm_client())
