"""Per-user request limiter for expensive destination grouping."""

from functools import lru_cache

from app.core.config import get_settings
from app.core.provider_usage import PerUserRequestLimiter


class GeoGroupLimiter(PerUserRequestLimiter):
    message = "Too many destination grouping requests. Try again shortly."
    code = "geo_group_rate_limit_exceeded"


@lru_cache(maxsize=8)
def _limiter(limit: int) -> GeoGroupLimiter:
    return GeoGroupLimiter(limit=limit)


def get_geo_group_limiter() -> GeoGroupLimiter:
    return _limiter(get_settings().geo_group_requests_per_minute)
