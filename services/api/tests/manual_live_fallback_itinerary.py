"""Opt-in live probe: does each fallback model produce a valid itinerary?

Runs the real itinerary pipeline (prompt, strict JSON schema, validation) against an
isolated test database seeded with real Davao destinations, forcing ONE model per run
with no fallback chain. It sends real requests with the keys from your local .env
(GROQ_API_KEY, and FALLBACK_LLM_API_KEY for the Gemini models) and uses a little quota.

Run with: python -m pytest -q -s tests/manual_live_fallback_itinerary.py
Override the models with LAKBAY_PROBE_GROQ_MODEL / LAKBAY_PROBE_FALLBACK_MODELS
(comma separated).
"""

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
from tests.test_phase5_ai_itineraries import create_destination, user_headers

PLACE_NAMES = (
    "Aqua Water Park",
    "Eden Nature Park",
    "Digos City Eco Park and Arboretum",
)
CATALOG = SEED_DESTINATIONS + CURATED_VISITOR_DESTINATIONS + DISCOVERY_VISITOR_DESTINATIONS

GROQ_MODEL = os.environ.get("LAKBAY_PROBE_GROQ_MODEL", "qwen/qwen3.8-27b")
FALLBACK_MODELS = [
    model.strip()
    for model in os.environ.get(
        "LAKBAY_PROBE_FALLBACK_MODELS", "gemini-3.5-flash-lite,gemini-3.1-flash-lite"
    ).split(",")
    if model.strip()
]
TARGETS = [("groq", GROQ_MODEL)] + [("fallback_llm", model) for model in FALLBACK_MODELS]


@pytest.mark.parametrize("provider,model_id", TARGETS, ids=[t[1] for t in TARGETS])
def test_itinerary_on_single_model(client, monkeypatch, provider, model_id):
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
    admin = client.post(
        "/api/v1/auth/register/admin",
        json={
            "full_name": "Admin User",
            "email": "admin@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "admin_registration_code": "admin-test-code",
        },
    )
    assert admin.status_code == 201, admin.json()
    admin_auth = {"Authorization": f"Bearer {admin.json()['tokens']['access_token']}"}

    place_ids = []
    for name in PLACE_NAMES:
        seed = next(place for place in CATALOG if place["name"] == name)
        place = DestinationCreate.model_validate(seed).model_dump(mode="json")
        place_ids.append(
            create_destination(client, headers=admin_auth, **place)["destination_id"]
        )

    response = client.post(
        "/api/v1/ai/itineraries/generate",
        headers=user_headers(client),
        json={
            "total_budget": "15000.00",
            "traveler_count": 4,
            "day_count": 2,
            "destination_ids": place_ids,
            "interests": ["nature", "water activities"],
            "travel_style": "relaxed group trip",
            "special_requirements": (
                "Start in Davao City. Visit all three chosen places over two days. "
                "Do not claim Digos City Eco Park is open without verified opening "
                "hours. Include realistic group costs and travel time."
            ),
            "allow_fallback": False,
        },
    )

    body = response.json()
    runs = body.get("model_runs") or body.get("error", {}).get("details", {}).get("model_runs", [])
    for run in runs:
        print(
            f"\n[{model_id}] status={run.get('status')} validation={run.get('validation_status')} "
            f"time={run.get('response_time_ms')}ms options={len(run.get('options') or [])} "
            f"tokens={run.get('prompt_tokens')}+{run.get('completion_tokens')} "
            f"error={run.get('error_message') or '-'}"
        )
    if not runs:
        print(f"\n[{model_id}] HTTP {response.status_code} {body.get('error', body)}")

    assert response.status_code == 200, f"{model_id}: HTTP {response.status_code}"
    assert runs and runs[0]["status"] == "succeeded"
    assert runs[0]["validation_status"] == "valid"
    assert len(runs[0]["options"]) >= 1
