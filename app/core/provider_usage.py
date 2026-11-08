"""Local or Redis-backed guards for outbound provider calls."""

import hashlib
import json
from collections import deque
from functools import lru_cache
from math import ceil
from threading import Lock
from time import monotonic
from typing import Any
from uuid import uuid4

from redis import Redis
from redis.exceptions import RedisError

from app.core.config import get_settings
from app.core.exceptions import LakbayAPIError


class SlidingWindowLimiter:
    def __init__(self) -> None:
        self._lock = Lock()
        self._requests: dict[str, deque[float]] = {}

    def reserve(
        self,
        key: str,
        *,
        limit: int,
        window_seconds: int = 60,
        amount: int = 1,
        code: str,
        message: str,
    ) -> None:
        self.reserve_many(
            [(key, limit, window_seconds, amount)],
            code=code,
            message=message,
        )

    def reserve_many(
        self,
        rules: list[tuple[str, int, int, int]],
        *,
        code: str,
        message: str,
    ) -> None:
        """Atomically check and reserve all (key, limit, window, amount) rules."""
        now = monotonic()
        with self._lock:
            for key, limit, window_seconds, amount in rules:
                history = self._requests.setdefault(key, deque())
                cutoff = now - window_seconds
                while history and history[0] <= cutoff:
                    history.popleft()
                if len(history) + amount > limit:
                    retry_after = (
                        max(1, ceil(history[0] + window_seconds - now))
                        if history else window_seconds
                    )
                    raise LakbayAPIError(
                        message,
                        code=code,
                        status_code=429,
                        details={"retry_after_seconds": retry_after},
                        headers={"Retry-After": str(retry_after)},
                    )
            for key, _, _, amount in rules:
                self._requests[key].extend([now] * amount)

    def clear(self) -> None:
        with self._lock:
            self._requests.clear()


class TTLCache:
    def __init__(self, max_entries: int = 2048) -> None:
        self._lock = Lock()
        self._entries: dict[str, tuple[float, Any]] = {}
        self._max_entries = max_entries

    def get(self, key: str) -> Any | None:
        now = monotonic()
        with self._lock:
            entry = self._entries.get(key)
            if entry is None:
                return None
            expires_at, value = entry
            if expires_at <= now:
                del self._entries[key]
                return None
            return value

    def put(self, key: str, value: Any, *, ttl_seconds: int) -> None:
        if ttl_seconds <= 0:
            return
        now = monotonic()
        with self._lock:
            if len(self._entries) >= self._max_entries:
                self._entries = {
                    stored_key: entry
                    for stored_key, entry in self._entries.items()
                    if entry[0] > now
                }
            if len(self._entries) >= self._max_entries:
                oldest_key = min(self._entries, key=lambda item: self._entries[item][0])
                del self._entries[oldest_key]
            self._entries[key] = (now + ttl_seconds, value)

    def clear(self) -> None:
        with self._lock:
            self._entries.clear()


_RESERVE_SCRIPT = """
local clock = redis.call('TIME')
local now = tonumber(clock[1]) * 1000 + math.floor(tonumber(clock[2]) / 1000)
local token = ARGV[#KEYS * 3 + 1]
for i = 1, #KEYS do
  local offset = (i - 1) * 3
  local limit = tonumber(ARGV[offset + 1])
  local window = tonumber(ARGV[offset + 2])
  local amount = tonumber(ARGV[offset + 3])
  redis.call('ZREMRANGEBYSCORE', KEYS[i], '-inf', now - window)
  if redis.call('ZCARD', KEYS[i]) + amount > limit then
    local oldest = redis.call('ZRANGE', KEYS[i], 0, 0, 'WITHSCORES')
    if #oldest == 0 then return math.ceil(window / 1000) end
    return math.max(1, math.ceil((tonumber(oldest[2]) + window - now) / 1000))
  end
end
for i = 1, #KEYS do
  local offset = (i - 1) * 3
  local window = tonumber(ARGV[offset + 2])
  local amount = tonumber(ARGV[offset + 3])
  for j = 1, amount do
    redis.call('ZADD', KEYS[i], now, token .. ':' .. i .. ':' .. j)
  end
  redis.call('PEXPIRE', KEYS[i], window)
end
return 0
"""


class RedisSlidingWindowLimiter:
    def __init__(self, client: Redis) -> None:
        self.client = client

    def reserve_many(
        self,
        rules: list[tuple[str, int, int, int]],
        *,
        code: str,
        message: str,
    ) -> None:
        if not rules:
            return
        keys = [f"{{lakbay-provider-usage}}:limit:{key}" for key, _, _, _ in rules]
        args = [item for _, limit, window, amount in rules
                for item in (limit, window * 1000, amount)]
        args.append(uuid4().hex)
        try:
            retry_after = int(self.client.eval(_RESERVE_SCRIPT, len(keys), *keys, *args))
        except (RedisError, TypeError, ValueError) as exc:
            raise _store_unavailable() from exc
        if retry_after:
            raise LakbayAPIError(
                message,
                code=code,
                status_code=429,
                details={"retry_after_seconds": retry_after},
                headers={"Retry-After": str(retry_after)},
            )


class RedisTTLCache:
    def __init__(self, client: Redis) -> None:
        self.client = client

    def _key(self, key: str) -> str:
        digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
        return f"{{lakbay-provider-usage}}:cache:{digest}"

    def get(self, key: str) -> Any | None:
        try:
            value = self.client.get(self._key(key))
        except RedisError as exc:
            raise _store_unavailable() from exc
        try:
            return json.loads(value) if value is not None else None
        except (TypeError, ValueError) as exc:
            raise _store_unavailable() from exc

    def put(self, key: str, value: Any, *, ttl_seconds: int) -> None:
        if ttl_seconds <= 0:
            return
        try:
            self.client.set(self._key(key), json.dumps(value), ex=ttl_seconds)
        except RedisError as exc:
            raise _store_unavailable() from exc


@lru_cache(maxsize=4)
def _redis_client(url: str) -> Redis:
    try:
        return Redis.from_url(
            url,
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
    except (RedisError, ValueError) as exc:
        raise _store_unavailable() from exc


def _store_unavailable() -> LakbayAPIError:
    return LakbayAPIError(
        "Provider usage store is unavailable. Please try again shortly.",
        code="provider_usage_store_unavailable",
        status_code=503,
    )


class ProviderLimiter:
    def __init__(self) -> None:
        self.local = SlidingWindowLimiter()

    def reserve(self, key: str, *, limit: int, window_seconds: int = 60,
                amount: int = 1, code: str, message: str) -> None:
        self.reserve_many([(key, limit, window_seconds, amount)], code=code, message=message)

    def reserve_many(self, rules: list[tuple[str, int, int, int]], *,
                     code: str, message: str) -> None:
        url = get_settings().provider_usage_redis_url
        if url:
            RedisSlidingWindowLimiter(_redis_client(url)).reserve_many(
                rules, code=code, message=message,
            )
        else:
            self.local.reserve_many(rules, code=code, message=message)

    def clear(self) -> None:
        self.local.clear()


class ProviderCache:
    def __init__(self) -> None:
        self.local = TTLCache()

    def get(self, key: str) -> Any | None:
        url = get_settings().provider_usage_redis_url
        return (RedisTTLCache(_redis_client(url)).get(key) if url
                else self.local.get(key))

    def put(self, key: str, value: Any, *, ttl_seconds: int) -> None:
        url = get_settings().provider_usage_redis_url
        if url:
            RedisTTLCache(_redis_client(url)).put(key, value, ttl_seconds=ttl_seconds)
        else:
            self.local.put(key, value, ttl_seconds=ttl_seconds)

    def clear(self) -> None:
        self.local.clear()
