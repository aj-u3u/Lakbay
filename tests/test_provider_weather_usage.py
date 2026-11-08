import asyncio

import httpx
import pytest

from app.core.config import Settings
from app.core.exceptions import LakbayAPIError
from app.features.weather.service import WeatherService, _weather_cache, _weather_limiter


@pytest.fixture(autouse=True)
def clear_weather_guards():
    _weather_cache.clear()
    _weather_limiter.clear()
    yield
    _weather_cache.clear()
    _weather_limiter.clear()


def _mock_weather(monkeypatch, responses):
    calls = []

    def handler(request):
        path = request.url.path.removeprefix("/data/2.5")
        calls.append(path)
        return httpx.Response(200, json=responses[path])

    transport = httpx.MockTransport(handler)
    real_client = httpx.AsyncClient
    monkeypatch.setattr(
        "app.features.weather.service.httpx.AsyncClient",
        lambda **kwargs: real_client(transport=transport, **kwargs),
    )
    return calls


def test_current_weather_cache_saves_provider_calls_and_misses_are_limited(monkeypatch):
    calls = _mock_weather(monkeypatch, {"/weather": {"weather": [{"main": "Clear"}]}})
    settings = Settings(
        _env_file=None,
        openweather_api_key="test-key",
        openweather_requests_per_minute=1,
        openweather_current_cache_seconds=600,
    )
    service = WeatherService(None, settings)

    first = asyncio.run(service.current_weather(lat=7.0731, lng=125.6128))
    second = asyncio.run(service.current_weather(lat=7.0731, lng=125.6128))
    assert first.condition.main == second.condition.main == "Clear"
    assert calls == ["/weather"]

    with pytest.raises(LakbayAPIError) as error:
        asyncio.run(service.current_weather(lat=7.074, lng=125.6128))
    assert error.value.status_code == 429
    assert error.value.code == "openweather_rate_limit_exceeded"
    assert int(error.value.headers["Retry-After"]) >= 1
    assert calls == ["/weather"]


def test_forecast_caches_both_provider_responses(monkeypatch):
    calls = _mock_weather(
        monkeypatch,
        {
            "/weather": {"weather": [{"main": "Clear"}]},
            "/forecast": {"list": [], "city": {"name": "Davao City"}},
        },
    )
    settings = Settings(
        _env_file=None,
        openweather_api_key="test-key",
        openweather_requests_per_minute=2,
    )
    service = WeatherService(None, settings)

    asyncio.run(service.forecast(lat=7.0731, lng=125.6128))
    asyncio.run(service.forecast(lat=7.0731, lng=125.6128))
    assert calls == ["/weather", "/forecast"]


def test_provider_429_is_forwarded_with_retry_time(monkeypatch):
    calls = []

    def handler(request):
        calls.append(request)
        return httpx.Response(429, headers={"retry-after": "9"})

    real_client = httpx.AsyncClient
    monkeypatch.setattr(
        "app.features.weather.service.httpx.AsyncClient",
        lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs),
    )
    service = WeatherService(None, Settings(_env_file=None, openweather_api_key="test-key"))

    with pytest.raises(LakbayAPIError) as error:
        asyncio.run(service.current_weather(lat=7.0731, lng=125.6128))
    assert error.value.status_code == 429
    assert error.value.headers["Retry-After"] == "9"
    assert len(calls) == 1


def test_rolling_30_day_weather_budget_blocks_provider_call(monkeypatch):
    calls = _mock_weather(monkeypatch, {"/weather": {"weather": [{"main": "Clear"}]}})
    settings = Settings(
        _env_file=None,
        openweather_api_key="test-key",
        openweather_requests_per_minute=45,
        openweather_requests_per_30_days=2,
        openweather_current_cache_seconds=0,
    )
    service = WeatherService(None, settings)

    asyncio.run(service.current_weather(lat=7.0731, lng=125.6128))
    asyncio.run(service.current_weather(lat=7.0731, lng=125.6128))
    with pytest.raises(LakbayAPIError) as error:
        asyncio.run(service.current_weather(lat=7.0731, lng=125.6128))
    assert error.value.status_code == 429
    assert len(calls) == 2
