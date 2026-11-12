import asyncio

import httpx
import pytest

from app.core.config import Settings, get_settings
from app.integrations.groq.client import GroqClient, _groq_model_limiter
from app.integrations.groq.errors import GroqRateLimitError
from app.integrations.groq.model_selector import select_fallback_model
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


def test_fallback_selection_prefers_separate_provider():
    settings = Settings(
        _env_file=None,
        groq_model_fallback="other-groq-model",
        fallback_llm_api_key="key",
        fallback_llm_model="gemini-flash",
    )
    selection = select_fallback_model(settings=settings, primary_model_id="primary")
    assert selection.provider == "fallback_llm"
    assert selection.model_id == "gemini-flash"
    assert selection.fallback_used is True


def test_fallback_selection_stays_on_groq_without_second_provider():
    settings = Settings(_env_file=None, groq_model_fallback="other-groq-model")
    selection = select_fallback_model(settings=settings, primary_model_id="primary")
    assert selection.provider == "groq"


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
    assert [call["provider"] for call in fake.calls] == ["groq", "fallback_llm"]


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
    assert len(fake.calls) == 2


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
