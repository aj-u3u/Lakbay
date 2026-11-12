"""Stress checks for the Groq rate-limit fallback. Run explicitly:

    python -m pytest tests/stress_ai_rate_limit.py -q -s

All providers are simulated; no real Groq/Gemini traffic is sent.
"""

import asyncio
import threading
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

import httpx
import pytest

from app.core.config import Settings, get_settings
from app.integrations.groq.client import GroqClient, _groq_model_limiter, get_groq_client
from app.integrations.groq.errors import GroqRateLimitError
from app.integrations.groq.schemas import GroqChatCompletion
from tests.test_phase5_ai_itineraries import configure_ai


@pytest.fixture(autouse=True)
def clear_limiter():
    _groq_model_limiter.clear()
    yield
    _groq_model_limiter.clear()


def test_burst_never_exceeds_provider_caps(monkeypatch):
    """300 concurrent calls per provider: provider traffic must stay within local caps."""
    hits = Counter()

    def handler(request):
        hits[request.headers["authorization"]] += 1
        return httpx.Response(200, json={"choices": [{"message": {"content": "OK"}}]})

    transport = httpx.MockTransport(handler)
    real_client = httpx.AsyncClient
    monkeypatch.setattr(
        "app.integrations.groq.client.httpx.AsyncClient",
        lambda **kwargs: real_client(transport=transport, **kwargs),
    )
    settings = Settings(
        _env_file=None,
        groq_api_key="groq",
        groq_model_requests_per_minute=20,
        fallback_llm_api_key="fallback",
        fallback_llm_requests_per_minute=10,
        groq_max_retries=1,
    )
    client = GroqClient(settings)

    async def run():
        jobs = [client.create_chat_completion(model="m", messages=[]) for _ in range(300)]
        jobs += [
            client.create_chat_completion(model="m", messages=[], provider="fallback_llm")
            for _ in range(300)
        ]
        return await asyncio.gather(*jobs, return_exceptions=True)

    results = asyncio.run(run())
    outcomes = Counter(
        "ok" if isinstance(r, GroqChatCompletion)
        else "429" if isinstance(r, GroqRateLimitError)
        else f"UNEXPECTED:{type(r).__name__}"
        for r in results
    )
    print("burst outcomes:", dict(outcomes), "provider hits:", dict(hits))

    assert set(outcomes) <= {"ok", "429"}
    assert hits["Bearer groq"] == 20
    assert hits["Bearer fallback"] == 10
    assert outcomes["ok"] == 30


class CappedFake:
    """Thread-safe fake: each provider answers N calls, then rate limits."""

    def __init__(self, groq_cap: int, fallback_cap: int) -> None:
        self.lock = threading.Lock()
        self.caps = {"groq": groq_cap, "fallback_llm": fallback_cap}
        self.served = Counter()

    async def create_chat_completion(self, *, model, messages, response_format=None, provider="groq"):
        with self.lock:
            if self.served[provider] >= self.caps[provider]:
                raise GroqRateLimitError("Groq rate limit reached.", retry_after_seconds=30)
            self.served[provider] += 1
        await asyncio.sleep(0.01)
        return GroqChatCompletion(
            content=f"answer from {provider}", model=model,
            prompt_tokens=1, completion_tokens=1, total_tokens=2,
        )


def test_many_users_through_endpoint(client, monkeypatch):
    """60 concurrent chats from 12 users; primary allows 15, fallback allows 10."""
    configure_ai(monkeypatch)
    monkeypatch.setenv("FALLBACK_LLM_API_KEY", "key")
    monkeypatch.setenv("FALLBACK_LLM_MODEL", "gemini-flash")
    get_settings.cache_clear()
    fake = CappedFake(groq_cap=15, fallback_cap=10)
    client.app.dependency_overrides[get_groq_client] = lambda: fake

    tokens = []
    for i in range(12):
        response = client.post(
            "/api/v1/auth/register",
            json={
                "full_name": f"User {i}", "email": f"user{i}@example.com",
                "password": "password123", "confirm_password": "password123",
            },
        )
        tokens.append(response.json()["tokens"]["access_token"])

    def send(index):
        headers = {"Authorization": f"Bearer {tokens[index % len(tokens)]}"}
        response = client.post("/api/v1/ai/chat", headers=headers, json={"message": "hi"})
        return response.status_code

    # The test DB is one shared in-memory SQLite connection, which cannot take
    # overlapping commits, so requests run one at a time here. Real concurrency
    # against the limiter and providers is covered by the burst test above.
    with ThreadPoolExecutor(max_workers=1) as pool:
        statuses = list(pool.map(send, range(60)))

    counts = Counter(statuses)
    print("endpoint statuses:", dict(counts), "served:", dict(fake.served))

    assert set(counts) <= {200, 429}, f"unexpected statuses: {counts}"
    assert fake.served["groq"] == 15
    assert fake.served["fallback_llm"] == 10
    assert counts[200] == 25
    assert counts[429] == 35
