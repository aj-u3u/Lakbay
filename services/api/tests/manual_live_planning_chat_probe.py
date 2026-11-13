"""Opt-in live probe: does each model keep the planning chat working?

Sends the same trip messages through the real /api/v1/ai/chat planning path against an
isolated test database seeded with real Davao destinations, forcing ONE model per run
with no fallback chain. Prints whether the model returned valid planning JSON, whether a
destination was selected, and how many suggestion cards the app would show. Uses real
requests and the keys from your local .env.

Run with: python -m pytest -q -s tests/manual_live_planning_chat_probe.py
"""

import json
import os

import pytest

from app.core.config import get_settings
from app.features.destinations.schemas import DestinationCreate
from app.integrations.groq.model_selector import ModelSelection
from app.seeds.davao_destinations import (
    CURATED_VISITOR_DESTINATIONS,
    DISCOVERY_VISITOR_DESTINATIONS,
    SEED_DESTINATIONS,
)
import app.features.ai.router as ai_router_module
from tests.test_phase5_ai_itineraries import create_destination, user_headers
from tests.test_planning_chat import CandidateOSRM

CATALOG = SEED_DESTINATIONS + CURATED_VISITOR_DESTINATIONS + DISCOVERY_VISITOR_DESTINATIONS
GROQ_MODELS = [
    m.strip() for m in os.environ.get(
        "LAKBAY_PROBE_GROQ_MODELS", "openai/gpt-oss-120b,qwen/qwen3.8-27b"
    ).split(",") if m.strip()
]
FALLBACK_MODELS = [
    m.strip() for m in os.environ.get(
        "LAKBAY_PROBE_FALLBACK_MODELS", "gemini-3.5-flash-lite,gemini-3.1-flash-lite"
    ).split(",") if m.strip()
]
TARGETS = [("groq", m) for m in GROQ_MODELS] + [("fallback_llm", m) for m in FALLBACK_MODELS]

MESSAGES = [
    "I want to go to Samal Island",
    "I want a beach trip in Samal for 2 days with a 10000 budget",
    "Suggest nature places to visit in Davao",
]


def _seed(client, admin_auth):
    samal = [s for s in CATALOG if "samal" in str(s).lower()][:4]
    others = [s for s in CATALOG if s not in samal][:8]
    for seed in samal + others:
        place = DestinationCreate.model_validate(seed).model_dump(mode="json")
        create_destination(client, headers=admin_auth, **place)


@pytest.mark.parametrize("provider,model_id", TARGETS, ids=[t[1] for t in TARGETS])
def test_planning_chat_on_single_model(client, monkeypatch, provider, model_id):
    settings = get_settings()
    if provider == "groq" and not settings.groq_api_key:
        pytest.skip("GROQ_API_KEY is not set in the local .env")
    if provider == "fallback_llm" and not settings.fallback_llm_api_key:
        pytest.skip("FALLBACK_LLM_API_KEY is not set in the local .env")

    monkeypatch.setattr(
        "app.features.ai.service.select_primary_model",
        lambda *, settings, model_role: ModelSelection(
            model_role="default", model_id=model_id, provider=provider
        ),
    )
    monkeypatch.setattr(ai_router_module, "get_osrm_client", lambda: CandidateOSRM())
    admin = client.post(
        "/api/v1/auth/register/admin",
        json={
            "full_name": "Admin User", "email": "admin@example.com",
            "password": "password123", "confirm_password": "password123",
            "admin_registration_code": "admin-test-code",
        },
    )
    assert admin.status_code == 201, admin.json()
    _seed(client, {"Authorization": f"Bearer {admin.json()['tokens']['access_token']}"})
    traveler = user_headers(client)

    print(f"\n=== {model_id} ===")
    invalid = 0
    for message in MESSAGES:
        response = client.post(
            "/api/v1/ai/chat",
            headers=traveler,
            json={
                "message": message,
                "allow_fallback": False,
                "use_rag": True,
                "input_revision": 1,
                "planning_state": {
                    "origin": {"label": "Davao City"},
                    "destination_ids": [],
                    "interests": [],
                },
            },
        )
        if response.status_code != 200:
            err = response.json().get("error", {})
            print(f"  [{message[:38]}] HTTP {response.status_code} {err.get('code')}")
            invalid += 1
            continue
        body = response.json()
        planning = body.get("planning") or {}
        updates = planning.get("state_updates") or {}
        cards = len(planning.get("recommendations") or [])
        status = planning.get("update_status")
        invalid += status == "invalid_output"
        print(
            f"  [{message[:38]}] update={status} "
            f"destination_ids={updates.get('destination_ids')} "
            f"interests={updates.get('interests')} cards={cards} "
            f"reply={body['chat_response'][:90].encode('ascii', 'replace').decode()!r}"
        )
    assert invalid == 0, f"{model_id}: {invalid} of {len(MESSAGES)} replies were unusable"
