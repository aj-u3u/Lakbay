"""Opt-in live Groq comparison with an isolated destination database.

Run with: python -m pytest -q -s tests/manual_live_groq_comparison.py
Set LAKBAY_COMPARISON_RUN=1, 2, or 3 to save separate runs.
"""

import json
import os
from pathlib import Path

from app.features.destinations.schemas import DestinationCreate
from app.integrations.groq.client import GroqClient
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
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "outputs" / "groq-comparison-2026-11-05"
CATALOG = SEED_DESTINATIONS + CURATED_VISITOR_DESTINATIONS + DISCOVERY_VISITOR_DESTINATIONS


def test_fixed_group_trip_across_three_models(client, monkeypatch):
    original_parse = GroqClient._parse_response

    def report_provider_error(self, provider_response):
        if provider_response.status_code >= 400:
            error = provider_response.json().get("error", {})
            print(
                "provider_rejection",
                provider_response.status_code,
                error.get("type"),
                error.get("code"),
                str(error.get("message", ""))[:240],
            )
        return original_parse(self, provider_response)

    monkeypatch.setattr(GroqClient, "_parse_response", report_provider_error)
    admin_response = client.post(
        "/api/v1/auth/register/admin",
        json={
            "full_name": "Admin User",
            "email": "admin@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "admin_registration_code": "admin-test-code",
        },
    )
    assert admin_response.status_code == 201, admin_response.json()
    admin_auth = {
        "Authorization": f"Bearer {admin_response.json()['tokens']['access_token']}"
    }
    place_ids = []
    for name in PLACE_NAMES:
        seed = next(place for place in CATALOG if place["name"] == name)
        place = DestinationCreate.model_validate(seed).model_dump(mode="json")
        created = create_destination(client, headers=admin_auth, **place)
        place_ids.append(created["destination_id"])

    request = {
        "total_budget": "15000.00",
        "traveler_count": 4,
        "day_count": 2,
        "destination_ids": place_ids,
        "interests": ["nature", "water activities"],
        "travel_style": "relaxed group trip",
        "special_requirements": (
            "Start in Davao City. Use a private car for land travel, but account "
            "for the separate Samal ferry. Visit all three chosen places over "
            "two days. Do not claim Digos City Eco Park is open without verified "
            "opening hours. Include realistic group costs and travel time."
        ),
        "compare_models": True,
        "allow_fallback": False,
    }
    response = client.post(
        "/api/v1/ai/itineraries/generate",
        headers=user_headers(client),
        json=request,
    )
    run = os.environ.get("LAKBAY_COMPARISON_RUN", "1")
    if run not in {"1", "2", "3"}:
        raise ValueError("LAKBAY_COMPARISON_RUN must be 1, 2, or 3")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    artifact = {"request": request, "http_status": response.status_code, "response": response.json()}
    (OUTPUT_DIR / f"run_{run}.json").write_text(
        json.dumps(artifact, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"run={run} http_status={response.status_code}")
    for model_run in response.json().get("model_runs", []):
        print(
            model_run["model_id"], model_run["status"],
            model_run["validation_status"], model_run["response_time_ms"],
            "ms", len(model_run["options"]), "options",
            model_run.get("error_message") or "",
        )
    assert response.status_code == 200
