"""Per-user limit for the route preview and optimization endpoints."""

from typing import Annotated

from fastapi import Depends

from app.core.config import get_settings
from app.core.dependencies import get_current_user
from app.core.provider_usage import ProviderLimiter
from app.features.users.models import User

# Process-local unless PROVIDER_USAGE_REDIS_URL is configured.
_route_request_limiter = ProviderLimiter()


def enforce_route_request_limit(
    current_user: Annotated[User, Depends(get_current_user)],
) -> None:
    _route_request_limiter.reserve(
        f"routes:user:{current_user.user_id}",
        limit=get_settings().route_requests_per_minute,
        code="route_rate_limited",
        message="Too many route requests. Please try again shortly.",
    )
