import fakeredis
import pytest
from redis.exceptions import ConnectionError
from types import SimpleNamespace

from app.core.exceptions import LakbayAPIError
from app.core.provider_usage import (
    ProviderCache,
    ProviderLimiter,
    RedisSlidingWindowLimiter,
    RedisTTLCache,
)


def test_two_clients_share_atomic_limit_and_cache():
    server = fakeredis.FakeServer()
    first = fakeredis.FakeRedis(server=server, decode_responses=True)
    second = fakeredis.FakeRedis(server=server, decode_responses=True)
    first_limiter = RedisSlidingWindowLimiter(first)
    second_limiter = RedisSlidingWindowLimiter(second)
    rules = [("groq:model:test", 1, 60, 1)]

    first_limiter.reserve_many(rules, code="limit", message="Busy")
    with pytest.raises(LakbayAPIError) as error:
        second_limiter.reserve_many(rules, code="limit", message="Busy")
    assert error.value.status_code == 429
    assert int(error.value.headers["Retry-After"]) >= 1

    RedisTTLCache(first).put("weather:location", {"temp": 25}, ttl_seconds=60)
    assert RedisTTLCache(second).get("weather:location") == {"temp": 25}


def test_rejected_multi_rule_does_not_consume_other_redis_allowance():
    client = fakeredis.FakeRedis(decode_responses=True)
    limiter = RedisSlidingWindowLimiter(client)
    limiter.reserve_many([("app", 1, 86400, 1)], code="limit", message="Busy")

    with pytest.raises(LakbayAPIError):
        limiter.reserve_many(
            [("user", 1, 86400, 1), ("app", 1, 86400, 1)],
            code="limit", message="Busy",
        )
    limiter.reserve_many([("user", 1, 86400, 1)], code="limit", message="Busy")


def test_redis_failure_fails_closed():
    class BrokenRedis:
        def eval(self, *args):
            raise ConnectionError("unavailable")

    with pytest.raises(LakbayAPIError) as error:
        RedisSlidingWindowLimiter(BrokenRedis()).reserve_many(
            [("app", 1, 60, 1)], code="limit", message="Busy",
        )
    assert error.value.status_code == 503
    assert error.value.code == "provider_usage_store_unavailable"


def test_configured_proxies_use_shared_redis(monkeypatch):
    import app.core.provider_usage as usage

    client = fakeredis.FakeRedis(decode_responses=True)
    monkeypatch.setattr(
        usage, "get_settings",
        lambda: SimpleNamespace(provider_usage_redis_url="redis://test"),
    )
    monkeypatch.setattr(usage, "_redis_client", lambda url: client)
    first = ProviderLimiter()
    second = ProviderLimiter()
    first.reserve("shared", limit=1, code="limit", message="Busy")
    with pytest.raises(LakbayAPIError):
        second.reserve("shared", limit=1, code="limit", message="Busy")

    ProviderCache().put("weather", {"ok": True}, ttl_seconds=60)
    assert ProviderCache().get("weather") == {"ok": True}
