"""Optional routing dependencies and a bounded per-user development limiter."""

from collections import deque
from functools import lru_cache
from math import ceil
from threading import Lock
from time import monotonic
from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.dependencies import get_current_user
from app.core.exceptions import LakbayAPIError
from app.db.session import get_db_session
from app.features.planning.schemas import PlanningPreviewRequest
from app.features.routes.service import RouteService
from app.features.users.models import User
from app.integrations.osrm.client import get_osrm_client


class PlanningRouteLimiter:
    """Sliding window per worker; a shared limiter is needed for multiple workers."""

    def __init__(self, limit: int = 10, window_seconds: float = 60) -> None:
        self.limit = limit
        self.window_seconds = window_seconds
        self._requests: dict[int, deque[float]] = {}
        self._lock = Lock()

    def check(self, user_id: int) -> None:
        now = monotonic()
        cutoff = now - self.window_seconds
        with self._lock:
            # Prune expired users when the bounded registry needs space.
            if user_id not in self._requests and len(self._requests) >= 10000:
                self._requests = {
                    key: history for key, history in self._requests.items()
                    if history and history[-1] > cutoff
                }
                if len(self._requests) >= 10000:
                    self._reject(1)
            history = self._requests.setdefault(user_id, deque())
            while history and history[0] <= cutoff:
                history.popleft()
            if len(history) >= self.limit:
                self._reject(max(1, ceil(history[0] + self.window_seconds - now)))
            history.append(now)

    @staticmethod
    def _reject(retry_after_seconds: int) -> None:
        raise LakbayAPIError(
            "Too many planning route requests. Try again shortly.",
            code="planning_route_rate_limit_exceeded",
            status_code=429,
            details={"retry_after_seconds": retry_after_seconds},
        )


@lru_cache(maxsize=8)
def _route_limiter(limit: int) -> PlanningRouteLimiter:
    return PlanningRouteLimiter(limit=limit)


def get_planning_route_limiter() -> PlanningRouteLimiter:
    return _route_limiter(get_settings().planning_route_requests_per_minute)


def enforce_planning_route_limit(
    data: PlanningPreviewRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    limiter: Annotated[PlanningRouteLimiter, Depends(get_planning_route_limiter)],
) -> None:
    if data.state.route_preferences is not None:
        limiter.check(current_user.user_id)


def get_planning_route_service(
    data: PlanningPreviewRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    route_limit: Annotated[None, Depends(enforce_planning_route_limit)],
) -> RouteService | None:
    # Construct a provider only when routing was explicitly requested.
    if data.state.route_preferences is None:
        return None
    return RouteService(session, get_osrm_client())
