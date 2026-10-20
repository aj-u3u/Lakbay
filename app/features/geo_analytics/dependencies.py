"""Per-user request limiter for expensive destination grouping."""

from collections import deque
from functools import lru_cache
from math import ceil
from threading import Lock
from time import monotonic

from app.core.config import get_settings
from app.core.exceptions import LakbayAPIError


class GeoGroupLimiter:
    """Sliding window per worker; production needs a shared store across workers."""

    def __init__(self, limit: int, window_seconds: float = 60) -> None:
        self.limit = limit
        self.window_seconds = window_seconds
        self._requests: dict[int, deque[float]] = {}
        self._lock = Lock()

    def check(self, user_id: int) -> None:
        now = monotonic()
        cutoff = now - self.window_seconds
        with self._lock:
            if user_id not in self._requests and len(self._requests) >= 10000:
                self._requests = {
                    key: history
                    for key, history in self._requests.items()
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
            "Too many destination grouping requests. Try again shortly.",
            code="geo_group_rate_limit_exceeded",
            status_code=429,
            details={"retry_after_seconds": retry_after_seconds},
        )


@lru_cache(maxsize=8)
def _limiter(limit: int) -> GeoGroupLimiter:
    return GeoGroupLimiter(limit=limit)


def get_geo_group_limiter() -> GeoGroupLimiter:
    return _limiter(get_settings().geo_group_requests_per_minute)
