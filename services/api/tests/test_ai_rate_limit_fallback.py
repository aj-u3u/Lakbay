import asyncio

import httpx
import pytest

from app.core.config import Settings, get_settings
from app.integrations.groq.client import GroqClient, _groq_model_limiter
from app.integrations.groq.errors import GroqRateLimitError
from app.integrations.groq.model_selector import select_fallback_model, select_fallback_models
from app.integrations.groq.client import get_groq_client
from app.integrations.groq.schemas import GroqChatCompletion
from tests.test_phase5_ai_itineraries import configure_ai, user_headers


@pytest.fixture(autouse=True)
def clear_limiter():
    _groq_model_limiter.clear()
    yield
    _groq_model_limiter.clear()


class RateLimitedThenOkClient:
    """Primary (groq) provider is rate limited; the fallback provider answers."""

    def __init__(self, *, fallback_fails: bool = False) -> None:
        self.calls: list[dict] = []
        self.fallback_fails = fallback_fails

    async def create_chat_completion(self, *, model, messages, response_format=None, provider="groq"):
        self.calls.append({"model": model, "provider": provider})
        if provider == "groq" or self.fallback_fails:
            raise GroqRateLimitError("Groq rate limit reached.", retry_after_seconds=30)
        return GroqChatCompletion(
            content="Fallback answer.", model=model,
            prompt_tokens=1, completion_tokens=1, total_tokens=2,
        )


def test_fallback_chain_order_is_groq_second_model_then_each_gemini_model():
    settings = Settings(
        _env_file=None,
        groq_model_fallback="qwen-model",
        fallback_llm_api_key="key",
        fallback_llm_model="gemini-a, gemini-b , gemini-a",
    )
    chain = select_fallback_models(settings=settings, primary_model_id="primary")
    assert [(item.provider, item.model_id) for item in chain] == [
        ("groq", "qwen-model"),
        ("fallback_llm", "gemini-a"),
        ("fallback_llm", "gemini-b"),
    ]
    assert all(item.fallback_used for item in chain)


def test_fallback_chain_skips_groq_model_equal_to_primary():
    settings = Settings(_env_file=None, groq_model_fallback="primary")
    assert select_fallback_models(settings=settings, primary_model_id="primary") == []
    assert select_fallback_model(settings=settings, primary_model_id="primary") is None


def test_fallback_chain_needs_both_key_and_model_for_second_provider():
    settings = Settings(_env_file=None, fallback_llm_model="gemini-a")
    assert select_fallback_models(settings=settings, primary_model_id="primary") == []


def test_chat_uses_fallback_provider_when_primary_is_rate_limited(client, monkeypatch):
    configure_ai(monkeypatch)
    monkeypatch.setenv("FALLBACK_LLM_API_KEY", "key")
    monkeypatch.setenv("FALLBACK_LLM_MODEL", "gemini-flash")
    get_settings.cache_clear()
    fake = RateLimitedThenOkClient()
    client.app.dependency_overrides[get_groq_client] = lambda: fake

    response = client.post(
        "/api/v1/ai/chat", headers=user_headers(client), json={"message": "hi"},
    )

    assert response.status_code == 200
    assert response.json()["chat_response"] == "Fallback answer."
    assert [call["provider"] for call in fake.calls] == ["groq", "groq", "fallback_llm"]


def test_chat_returns_429_when_every_provider_is_rate_limited(client, monkeypatch):
    configure_ai(monkeypatch)
    monkeypatch.setenv("FALLBACK_LLM_API_KEY", "key")
    monkeypatch.setenv("FALLBACK_LLM_MODEL", "gemini-flash")
    get_settings.cache_clear()
    fake = RateLimitedThenOkClient(fallback_fails=True)
    client.app.dependency_overrides[get_groq_client] = lambda: fake

    response = client.post(
        "/api/v1/ai/chat", headers=user_headers(client), json={"message": "hi"},
    )

    assert response.status_code == 429
    assert response.json()["error"]["code"] == "groq_rate_limit_exceeded"
    assert len(fake.calls) == 3


def _mock_transport(monkeypatch, handler):
    transport = httpx.MockTransport(handler)
    real_client = httpx.AsyncClient
    monkeypatch.setattr(
        "app.integrations.groq.client.httpx.AsyncClient",
        lambda **kwargs: real_client(transport=transport, **kwargs),
    )


def test_fallback_provider_uses_its_own_key_url_and_bucket(monkeypatch):
    seen = []

    def handler(request):
        seen.append(request)
        return httpx.Response(200, json={"choices": [{"message": {"content": "OK"}}]})

    _mock_transport(monkeypatch, handler)
    settings = Settings(
        _env_file=None,
        groq_api_key="groq-key",
        groq_model_requests_per_minute=1,
        fallback_llm_api_key="fallback-key",
        fallback_llm_base_url="https://fallback.example/v1",
        groq_max_retries=0,
    )
    client = GroqClient(settings)

    asyncio.run(client.create_chat_completion(model="m", messages=[]))
    # Same model name on the other provider must not share the exhausted Groq bucket.
    asyncio.run(client.create_chat_completion(model="m", messages=[], provider="fallback_llm"))

    assert seen[0].headers["authorization"] == "Bearer groq-key"
    assert seen[1].headers["authorization"] == "Bearer fallback-key"
    assert str(seen[1].url) == "https://fallback.example/v1/chat/completions"


def test_short_rate_limit_wait_is_retried(monkeypatch):
    responses = [
        httpx.Response(429, headers={"retry-after": "1"}),
        httpx.Response(200, json={"choices": [{"message": {"content": "OK"}}]}),
    ]
    _mock_transport(monkeypatch, lambda request: responses.pop(0))
    slept = []

    async def fake_sleep(seconds):
        slept.append(seconds)

    monkeypatch.setattr("app.integrations.groq.client.asyncio.sleep", fake_sleep)
    settings = Settings(_env_file=None, groq_api_key="key", groq_max_retries=1)

    result = asyncio.run(GroqClient(settings).create_chat_completion(model="m", messages=[]))

    assert result.content == "OK"
    assert slept == [1]


def test_daily_user_cap_counts_requests_not_fallback_attempts():
    from app.core.exceptions import LakbayAPIError
    from app.features.ai.service import _ai_user_limiter, _reserve_user_ai_call

    _ai_user_limiter.clear()
    settings = Settings(_env_file=None, groq_user_requests_per_day=2)
    _reserve_user_ai_call(7, settings)
    # A fallback attempt for the same request must not use the daily allowance.
    _reserve_user_ai_call(7, settings, count_daily=False)
    _reserve_user_ai_call(7, settings)
    with pytest.raises(LakbayAPIError) as error:
        _reserve_user_ai_call(7, settings)
    assert error.value.code == "ai_user_daily_limit_exceeded"
    assert error.value.status_code == 429
    _ai_user_limiter.clear()


def test_chat_prompt_keeps_recent_history_and_compact_json():
    import json as jsonlib

    from app.features.ai.schemas import AIChatMessage, AIChatRequest
    from app.integrations.groq.prompts import (
        CHAT_HISTORY_MESSAGE_CHARS,
        CHAT_HISTORY_MESSAGES,
        build_chat_messages,
    )

    history = [
        AIChatMessage(role="user" if i % 2 == 0 else "assistant", content=f"m{i}" + "x" * 1900)
        for i in range(12)
    ]
    messages = build_chat_messages(
        request=AIChatRequest(message="hello", history=history),
    )

    history_messages = messages[1:-1]
    assert len(history_messages) == CHAT_HISTORY_MESSAGES
    assert history_messages[0]["content"].startswith("m4")  # oldest 4 dropped
    assert all(len(m["content"]) <= CHAT_HISTORY_MESSAGE_CHARS for m in history_messages)
    last = messages[-1]["content"]
    assert ", " not in last and ": " not in last  # compact separators
    assert jsonlib.loads(last)["message"] == "hello"


def test_chat_logs_stage_timings_without_user_content(client, monkeypatch, caplog):
    import logging

    from tests.test_phase5_ai_itineraries import FakeGroqClient

    configure_ai(monkeypatch)
    fake = FakeGroqClient(["Hello there."])
    client.app.dependency_overrides[get_groq_client] = lambda: fake

    with caplog.at_level(logging.INFO, logger="app.ai.timing"):
        response = client.post(
            "/api/v1/ai/chat",
            headers=user_headers(client),
            json={"message": "secret-trip-message"},
        )

    assert response.status_code == 200
    lines = [r.getMessage() for r in caplog.records if r.name == "app.ai.timing"]
    stages = {line.split("stage=")[1].split()[0] for line in lines}
    assert {"retrieval", "model", "chat_total"} <= stages
    assert all("ms=" in line for line in lines)
    assert not any("secret-trip-message" in line for line in lines)
