import asyncio
import json

import httpx
import pytest

from app.core.config import Settings
from app.core.exceptions import LakbayAPIError
from app.features.ai.service import _ai_user_limiter, _reserve_user_ai_call
from app.integrations.groq.client import GroqClient, _groq_model_limiter
from app.integrations.groq.errors import GroqRateLimitError
from app.integrations.groq.itinerary_schema import ITINERARY_RESPONSE_FORMAT


@pytest.fixture(autouse=True)
def clear_groq_guards():
    _ai_user_limiter.clear()
    _groq_model_limiter.clear()
    yield
    _ai_user_limiter.clear()
    _groq_model_limiter.clear()


def _mock_groq(monkeypatch, response):
    calls = []

    def handler(request):
        calls.append(request)
        return response

    transport = httpx.MockTransport(handler)
    real_client = httpx.AsyncClient
    monkeypatch.setattr(
        "app.integrations.groq.client.httpx.AsyncClient",
        lambda **kwargs: real_client(transport=transport, **kwargs),
    )
    return calls


def test_model_guard_blocks_second_call_before_provider(monkeypatch):
    calls = _mock_groq(
        monkeypatch,
        httpx.Response(200, json={"choices": [{"message": {"content": "OK"}}]}),
    )
    settings = Settings(
        _env_file=None,
        groq_api_key="test-key",
        groq_model_requests_per_minute=1,
        groq_max_retries=0,
    )
    client = GroqClient(settings)

    first = asyncio.run(client.create_chat_completion(model="test-model", messages=[]))
    assert first.content == "OK"
    with pytest.raises(GroqRateLimitError) as error:
        asyncio.run(client.create_chat_completion(model="test-model", messages=[]))
    assert error.value.retry_after_seconds >= 1
    assert len(calls) == 1


def test_itinerary_request_sends_strict_schema_without_changing_plain_chat(monkeypatch):
    calls = _mock_groq(
        monkeypatch,
        httpx.Response(200, json={"choices": [{"message": {"content": "{}"}}]}),
    )
    settings = Settings(
        _env_file=None,
        groq_api_key="test-key",
        groq_model_requests_per_minute=5,
        groq_max_retries=0,
    )
    client = GroqClient(settings)

    asyncio.run(client.create_chat_completion(
        model="itinerary-model", messages=[],
        response_format=ITINERARY_RESPONSE_FORMAT,
    ))
    asyncio.run(client.create_chat_completion(model="chat-model", messages=[]))

    assert calls[0].headers["content-type"] == "application/json"
    assert json.loads(calls[0].content)["response_format"] == ITINERARY_RESPONSE_FORMAT
    assert "response_format" not in json.loads(calls[1].content)


def test_itinerary_strict_schema_requires_every_declared_object_field():
    assert ITINERARY_RESPONSE_FORMAT["type"] == "json_schema"
    assert ITINERARY_RESPONSE_FORMAT["json_schema"]["strict"] is True

    def check(node):
        if isinstance(node, dict):
            if node.get("type") == "object":
                assert node["additionalProperties"] is False
                assert set(node["required"]) == set(node["properties"])
            for value in node.values():
                check(value)
        elif isinstance(node, list):
            for value in node:
                check(value)

    check(ITINERARY_RESPONSE_FORMAT["json_schema"]["schema"])


def test_provider_429_uses_retry_after_without_immediate_retry(monkeypatch):
    calls = _mock_groq(monkeypatch, httpx.Response(429, headers={"retry-after": "7"}))
    settings = Settings(
        _env_file=None,
        groq_api_key="test-key",
        groq_model_requests_per_minute=5,
        groq_max_retries=3,
    )

    with pytest.raises(GroqRateLimitError) as error:
        asyncio.run(GroqClient(settings).create_chat_completion(model="test-model", messages=[]))
    assert error.value.retry_after_seconds == 7
    assert len(calls) == 1


def test_user_ai_guard_counts_attempts():
    settings = Settings(_env_file=None, groq_user_requests_per_minute=1)
    _reserve_user_ai_call(42, settings)
    with pytest.raises(LakbayAPIError) as error:
        _reserve_user_ai_call(42, settings)
    assert error.value.code == "ai_user_rate_limit_exceeded"
    assert error.value.status_code == 429


def test_daily_model_budget_blocks_provider_call(monkeypatch):
    calls = _mock_groq(
        monkeypatch,
        httpx.Response(200, json={"choices": [{"message": {"content": "OK"}}]}),
    )
    settings = Settings(
        _env_file=None,
        groq_api_key="test-key",
        groq_model_requests_per_minute=5,
        groq_model_requests_per_day=1,
        groq_max_retries=0,
    )
    client = GroqClient(settings)
    asyncio.run(client.create_chat_completion(model="test-model", messages=[]))
    with pytest.raises(GroqRateLimitError):
        asyncio.run(client.create_chat_completion(model="test-model", messages=[]))
    assert len(calls) == 1
