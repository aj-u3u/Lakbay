import json
from decimal import Decimal

import pytest

from app.core.config import get_settings
from app.integrations.groq.client import get_groq_client
from app.integrations.groq.itinerary_schema import ITINERARY_RESPONSE_FORMAT
from app.integrations.groq.schemas import GroqChatCompletion
from app.features.ai.validators import (
    AIItineraryCatalog,
    AIOutputValidationError,
    parse_and_validate_itinerary_output,
)


DESTINATION_PAYLOAD = {
    "name": "AI Test Beach",
    "description": "A destination for AI itinerary tests.",
    "district": "Davao Oriental",
    "location": "Mati City",
    "category": "beach",
    "vibes": "relaxed, coastal",
    "activities": "swimming, photography",
    "lat": 6.9487,
    "lng": 126.2542,
    "estimated_cost": "1500.00",
    "budget_class": "mid_range",
    "difficulty_level": "easy",
    "stay_duration_type": "full_day",
    "family_friendly": True,
    "group_friendly": True,
}


class FakeGroqClient:
    def __init__(self, responses: list[str]) -> None:
        self.responses = responses
        self.calls: list[dict] = []

    async def create_chat_completion(
        self,
        *,
        model: str,
        messages: list[dict[str, str]],
        response_format: dict | None = None,
        provider: str = "groq",
    ) -> GroqChatCompletion:
        self.calls.append({
            "model": model,
            "messages": messages,
            "response_format": response_format,
            "provider": provider,
        })
        content = self.responses.pop(0)

        return GroqChatCompletion(
            content=content,
            model=model,
            prompt_tokens=10,
            completion_tokens=20,
            total_tokens=30,
        )


def configure_ai(monkeypatch, *, comparison_enabled: bool = False) -> None:
    monkeypatch.setenv("GROQ_MODEL_DEFAULT", "default-model")
    monkeypatch.setenv("GROQ_MODEL_QUALITY", "quality-model")
    monkeypatch.setenv("GROQ_MODEL_FALLBACK", "fallback-model")
    monkeypatch.setenv("GROQ_MODEL_COMPARE_A", "compare-a-model")
    monkeypatch.setenv("GROQ_MODEL_COMPARE_B", "compare-b-model")
    monkeypatch.setenv("GROQ_MODEL_COMPARE_C", "compare-c-model")
    monkeypatch.setenv("AI_MODEL_COMPARISON_ENABLED", str(comparison_enabled).lower())
    monkeypatch.setenv("AI_ITINERARY_OPTION_COUNT", "5")
    # Keep tests independent of any fallback provider configured in a local .env.
    monkeypatch.setenv("FALLBACK_LLM_API_KEY", "")
    monkeypatch.setenv("FALLBACK_LLM_MODEL", "")
    get_settings.cache_clear()


def admin_headers(client) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register/admin",
        json={
            "full_name": "Admin User",
            "email": "admin@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "admin_registration_code": "admin-test-code",
        },
    )

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def user_headers(client) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "AI Traveler",
            "email": "traveler@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def create_destination(
    client,
    headers: dict[str, str] | None = None,
    **overrides,
) -> dict:
    response = client.post(
        "/api/v1/destinations",
        headers=headers or admin_headers(client),
        json={**DESTINATION_PAYLOAD, **overrides},
    )

    assert response.status_code == 201

    return response.json()


def create_accommodation(
    client,
    *,
    destination_id: int,
    headers: dict[str, str],
    **overrides,
) -> dict:
    response = client.post(
        f"/api/v1/destinations/{destination_id}/accommodations",
        headers=headers,
        json={
            "name": "AI Beach Stay",
            "room_type": "Standard Room",
            "price": "1800.00",
            "capacity": 2,
            **overrides,
        },
    )

    assert response.status_code == 201

    return response.json()


def create_transportation(
    client,
    *,
    destination_id: int,
    headers: dict[str, str],
    **overrides,
) -> dict:
    response = client.post(
        f"/api/v1/destinations/{destination_id}/transportations",
        headers=headers,
        json={
            "vehicle_type": "Van",
            "transport_mode": "public_transport",
            "route_from": "Davao City",
            "route_to": "Mati City",
            "price": "600.00",
            "duration_minutes": 240,
            **overrides,
        },
    )

    assert response.status_code == 201

    return response.json()


def itinerary_request(destination_id: int, **overrides) -> dict:
    payload = {
        "total_budget": "10000.00",
        "traveler_count": 2,
        "day_count": 2,
        "destination_ids": [destination_id],
        "accommodation_ids": [],
        "transportation_ids": [],
        "meal_cost_per_day": "500.00",
        "miscellaneous_cost": "300.00",
        "interests": ["beach", "food"],
        "travel_style": "relaxed",
    }
    payload.update(overrides)

    return payload


def valid_ai_response(
    *,
    destination_id: int,
    accommodation_id: int | None = None,
    transportation_id: int | None = None,
    option_count: int = 5,
    day_count: int = 2,
) -> str:
    options = []

    for option_number in range(1, option_count + 1):
        options.append(
            {
                "option_number": option_number,
                "title": f"Beach option {option_number}",
                "summary": "A valid beach itinerary draft.",
                "estimated_total_cost": f"{500 * day_count:.2f}",
                "is_over_budget": False,
                "days": [
                    {
                        "day": day,
                        "title": f"Day {day}",
                        "summary": "A planned travel day.",
                        "activities": [
                            {
                                "time": "08:00",
                                "title": "Visit destination",
                                "description": "Explore the selected destination.",
                                "destination_id": destination_id,
                                "accommodation_id": accommodation_id,
                                "transportation_id": transportation_id,
                                "estimated_cost": "500.00",
                                "notes": "Bring water.",
                            }
                        ],
                    }
                    for day in range(1, day_count + 1)
                ],
            }
        )

    return json.dumps({"options": options})


def test_ai_itinerary_generation_requires_authentication(client) -> None:
    response = client.post(
        "/api/v1/ai/itineraries/generate",
        json=itinerary_request(1),
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_ai_chat_requires_authentication(client) -> None:
    response = client.post(
        "/api/v1/ai/chat",
        json={"message": "Plan a beach trip in Mati."},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_ai_chat_uses_retrieved_lakbay_context(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    destination = create_destination(client, headers=admin)
    accommodation = create_accommodation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
    )
    fake_client = FakeGroqClient(
        ["AI Test Beach fits a relaxed Mati beach trip with nearby accommodation."]
    )
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "I want a relaxed beach stay in Mati with a room.",
            "history": [
                {
                    "role": "assistant",
                    "content": "Tell me what kind of Davao trip you want.",
                }
            ],
            "rag_limit": 4,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["mode"] == "rag_chat"
    assert body["chat_response"].startswith("AI Test Beach")
    assert body["retrieved_context"]
    assert any(
        item["source"] == "destination"
        and item["source_id"] == destination["destination_id"]
        for item in body["retrieved_context"]
    )
    assert any(
        item["source"] == "accommodation"
        and item["source_id"] == accommodation["accommodation_id"]
        for item in body["retrieved_context"]
    )

    prompt_payload = json.loads(fake_client.calls[0]["messages"][-1]["content"])
    assert prompt_payload["retrieved_lakbay_context"]
    assert any(
        item["source"] == "destination"
        and item["facts"]["name"] == "AI Test Beach"
        for item in prompt_payload["retrieved_lakbay_context"]
    )


def test_ai_chat_retrieves_requested_province_and_linked_rates(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    destination = create_destination(
        client,
        headers=admin,
        name="Samal Test Beach",
        district="Davao del Norte",
        location="Island Garden City of Samal",
    )
    accommodation = create_accommodation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
        name="Samal Test Stay",
    )
    transportation = create_transportation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
        vehicle_type="Ferry",
        route_from="Sasa Wharf",
        route_to="Samal",
        price="100.00",
        duration_minutes=30,
    )
    unrelated = create_destination(client, headers=admin)
    create_accommodation(
        client,
        destination_id=unrelated["destination_id"],
        headers=admin,
    )
    create_transportation(
        client,
        destination_id=unrelated["destination_id"],
        headers=admin,
    )
    fake_client = FakeGroqClient(["Test response."])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": (
                "i wanna travel the beaches in davao del norte, can you recommend "
                "that good for solo traveler and that's within my budget of "
                "15,000 and i wanna stay for 2 days."
            ),
        },
    )

    assert response.status_code == 200
    payload = json.loads(fake_client.calls[0]["messages"][-1]["content"])
    facts = payload["retrieved_lakbay_context"]
    assert {(item["source"], item["source_id"]) for item in facts} == {
        ("destination", destination["destination_id"]),
        ("accommodation", accommodation["accommodation_id"]),
        ("transportation", transportation["transportation_id"]),
    }
    assert all(
        item["facts"]["destination_id"] == destination["destination_id"]
        for item in facts
    )
    assert any(
        item["source"] == "transportation"
        and item["facts"]["vehicle_type"] == "Ferry"
        and item["facts"]["price"] == "100.00"
        for item in facts
    )
    coverage = payload["retrieval_coverage"]
    assert coverage["status"] == "matched"
    assert coverage["requested_locations"] == ["davao del norte"]
    assert coverage["interest"] == "beach"
    assert coverage["destinations"] == [
        {
            "destination_id": destination["destination_id"],
            "accommodation_status": "included",
            "transportation_status": "included",
        }
    ]
    assert coverage["truncated"] is False
    assert response.json()["retrieved_context"] == facts


def test_ai_chat_excludes_inactive_places_and_unavailable_rates(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    destination = create_destination(client, headers=admin)
    inactive_destination = create_destination(
        client,
        headers=admin,
        name="Inactive Mati Beach",
    )
    active_stay = create_accommodation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
    )
    unavailable_stay = create_accommodation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
        name="Unavailable Beach Stay",
    )
    unavailable_transport = create_transportation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
    )
    create_accommodation(
        client,
        destination_id=inactive_destination["destination_id"],
        headers=admin,
        name="Stay Under Inactive Beach",
    )
    create_transportation(
        client,
        destination_id=inactive_destination["destination_id"],
        headers=admin,
    )
    for path in (
        f"/api/v1/destinations/{inactive_destination['destination_id']}",
        f"/api/v1/accommodations/{unavailable_stay['accommodation_id']}",
        f"/api/v1/transportations/{unavailable_transport['transportation_id']}",
    ):
        assert client.delete(path, headers=admin).status_code == 200
    fake_client = FakeGroqClient(["Test response."])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={"message": "Plan a beach trip in Mati with a room and transportation."},
    )

    assert response.status_code == 200
    payload = json.loads(fake_client.calls[0]["messages"][-1]["content"])
    assert {
        (item["source"], item["source_id"])
        for item in payload["retrieved_lakbay_context"]
    } == {
        ("destination", destination["destination_id"]),
        ("accommodation", active_stay["accommodation_id"]),
    }
    assert payload["retrieval_coverage"]["destinations"] == [
        {
            "destination_id": destination["destination_id"],
            "accommodation_status": "included",
            "transportation_status": "no_available_records",
        }
    ]


@pytest.mark.parametrize("settings", [{"use_rag": False}, {"rag_limit": 0}])
def test_ai_chat_reports_disabled_retrieval(client, monkeypatch, settings) -> None:
    configure_ai(monkeypatch)
    create_destination(client)
    fake_client = FakeGroqClient(["Test response."])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={"message": "Plan a beach trip in Mati.", **settings},
    )

    assert response.status_code == 200
    assert response.json()["retrieved_context"] == []
    assert response.json()["mode"] == "chat"
    payload = json.loads(fake_client.calls[0]["messages"][-1]["content"])
    assert payload["retrieved_lakbay_context"] == []
    assert payload["retrieval_coverage"]["status"] == "disabled"
    assert payload["retrieval_coverage"]["destinations"] == []


def test_ai_chat_reports_no_matches_for_uncovered_province(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    create_destination(client)
    fake_client = FakeGroqClient(["Test response."])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={"message": "Recommend beaches in Davao del Norte."},
    )

    assert response.status_code == 200
    assert response.json()["retrieved_context"] == []
    payload = json.loads(fake_client.calls[0]["messages"][-1]["content"])
    assert payload["retrieved_lakbay_context"] == []
    assert payload["retrieval_coverage"]["status"] == "no_matches"
    assert payload["retrieval_coverage"]["requested_locations"] == ["davao del norte"]
    assert payload["retrieval_coverage"]["interest"] == "beach"


def test_ai_chat_distinguishes_missing_rates_from_context_limit(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    destination = create_destination(client, headers=admin)
    create_accommodation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
    )
    fake_client = FakeGroqClient(["Test response."])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={"message": "Recommend a beach in Mati.", "rag_limit": 1},
    )

    assert response.status_code == 200
    payload = json.loads(fake_client.calls[0]["messages"][-1]["content"])
    assert len(payload["retrieved_lakbay_context"]) == 1
    assert payload["retrieval_coverage"]["destinations"] == [
        {
            "destination_id": destination["destination_id"],
            "accommodation_status": "omitted_by_limit",
            "transportation_status": "no_available_records",
        }
    ]
    assert payload["retrieval_coverage"]["truncated"] is True


def test_user_can_generate_ai_itinerary_drafts(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    destination = create_destination(client, headers=admin)
    accommodation = create_accommodation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
    )
    transportation = create_transportation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
    )
    fake_client = FakeGroqClient(
        [
            valid_ai_response(
                destination_id=destination["destination_id"],
                accommodation_id=accommodation["accommodation_id"],
                transportation_id=transportation["transportation_id"],
            )
        ]
    )
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/itineraries/generate",
        headers=user_headers(client),
        json=itinerary_request(
            destination["destination_id"],
            accommodation_ids=[accommodation["accommodation_id"]],
            transportation_ids=[transportation["transportation_id"]],
        ),
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["options"]) == 5
    assert body["model_runs"][0]["status"] == "succeeded"
    assert body["model_runs"][0]["validation_status"] == "valid"
    assert body["model_runs"][0]["model_id"] == "quality-model"
    assert fake_client.calls[0]["model"] == "quality-model"


def test_ai_generation_retries_with_fallback_after_invalid_output(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    # The Groq fallback model is skipped for itineraries unless explicitly enabled.
    monkeypatch.setenv("GROQ_FALLBACK_FOR_ITINERARIES", "true")
    get_settings.cache_clear()
    destination = create_destination(client)
    fake_client = FakeGroqClient(
        [
            "not json",
            valid_ai_response(destination_id=destination["destination_id"]),
        ]
    )
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/itineraries/generate",
        headers=user_headers(client),
        json=itinerary_request(destination["destination_id"]),
    )

    assert response.status_code == 200
    body = response.json()
    assert [call["model"] for call in fake_client.calls] == [
        "quality-model",
        "fallback-model",
    ]
    assert body["model_runs"][0]["status"] == "failed"
    assert body["model_runs"][0]["validation_status"] == "invalid"
    assert body["model_runs"][1]["status"] == "succeeded"
    assert body["model_runs"][1]["model_id"] == "fallback-model"


def test_ai_generation_rejects_invented_destination_ids(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client)
    fake_client = FakeGroqClient([valid_ai_response(destination_id=999)])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/itineraries/generate",
        headers=user_headers(client),
        json=itinerary_request(
            destination["destination_id"],
            allow_fallback=False,
        ),
    )

    assert response.status_code == 502
    assert response.json()["error"]["code"] == "ai_generation_failed"
    assert response.json()["error"]["details"]["model_runs"][0]["status"] == "failed"


def test_ai_generation_rejects_too_few_options(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client)
    fake_client = FakeGroqClient(
        [
            valid_ai_response(
                destination_id=destination["destination_id"],
                option_count=4,
            )
        ]
    )
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/itineraries/generate",
        headers=user_headers(client),
        json=itinerary_request(
            destination["destination_id"],
            allow_fallback=False,
        ),
    )

    assert response.status_code == 502
    assert response.json()["error"]["code"] == "ai_generation_failed"


def test_quality_gate_requires_every_selected_place_without_planning_state() -> None:
    catalog = AIItineraryCatalog(
        destination_ids={1, 2}, accommodation_ids=set(), transportation_ids=set(),
        total_budget=Decimal("10000.00"), day_count=2, minimum_option_count=5,
        required_destination_ids={1, 2},
    )
    with pytest.raises(AIOutputValidationError, match="failed itinerary validation") as error:
        parse_and_validate_itinerary_output(
            content=valid_ai_response(destination_id=1), catalog=catalog,
        )
    assert "selected destination_id values: [1, 2]" in error.value.details[0]


def test_generation_blocks_missing_selected_place_without_planning_state(
    client, monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    first = create_destination(client, headers=admin)
    second = create_destination(client, headers=admin, name="Second Test Beach")
    fake_client = FakeGroqClient([
        valid_ai_response(destination_id=first["destination_id"]),
    ])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client
    response = client.post(
        "/api/v1/ai/itineraries/generate", headers=user_headers(client),
        json=itinerary_request(
            first["destination_id"],
            destination_ids=[first["destination_id"], second["destination_id"]],
            allow_fallback=False,
        ),
    )
    assert response.status_code == 502
    assert response.json()["error"]["details"]["model_runs"][0]["validation_status"] == "invalid"


def test_quality_gate_rejects_total_that_does_not_equal_activity_costs() -> None:
    catalog = AIItineraryCatalog(
        destination_ids={1}, accommodation_ids=set(), transportation_ids=set(),
        total_budget=Decimal("10000.00"), day_count=2, minimum_option_count=5,
        required_destination_ids={1},
    )
    payload = json.loads(valid_ai_response(destination_id=1))
    payload["options"][0]["estimated_total_cost"] = "3000.00"
    with pytest.raises(AIOutputValidationError, match="failed itinerary validation") as error:
        parse_and_validate_itinerary_output(content=json.dumps(payload), catalog=catalog)
    assert "sum of its activity costs" in error.value.details[0]


def test_quality_gate_discloses_unverified_hours_ferry_and_group_costs(
    client, monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(
        client, name="Samal Test Water Park", description="Ferry access required.",
        operating_hours="Unknown; confirm before visiting.",
    )
    fake_client = FakeGroqClient([
        valid_ai_response(destination_id=destination["destination_id"]),
    ])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client
    response = client.post(
        "/api/v1/ai/itineraries/generate", headers=user_headers(client),
        json=itinerary_request(destination["destination_id"], traveler_count=4),
    )
    assert response.status_code == 200, response.text
    warnings = response.json()["options"][0]["quality_warnings"]
    assert any("opening hours" in warning for warning in warnings)
    assert any("ferry or boat fare" in warning for warning in warnings)
    assert any("4 travelers" in warning for warning in warnings)
    assert any("Travel times" in warning for warning in warnings)


def test_ai_model_comparison_can_run_multiple_models(client, monkeypatch) -> None:
    configure_ai(monkeypatch, comparison_enabled=True)
    destination = create_destination(client)
    fake_client = FakeGroqClient(
        [
            valid_ai_response(destination_id=destination["destination_id"]),
            valid_ai_response(destination_id=destination["destination_id"]),
            valid_ai_response(destination_id=destination["destination_id"]),
        ]
    )
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/itineraries/generate",
        headers=user_headers(client),
        json=itinerary_request(
            destination["destination_id"],
            compare_models=True,
        ),
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["model_runs"]) == 3
    assert all(
        call["response_format"] == ITINERARY_RESPONSE_FORMAT
        for call in fake_client.calls
    )
    assert [run["model_id"] for run in body["model_runs"]] == [
        "compare-a-model",
        "compare-b-model",
        "compare-c-model",
    ]
