import json

from app.core.config import get_settings
from app.integrations.groq.client import get_groq_client
from app.integrations.groq.schemas import GroqChatCompletion


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
    ) -> GroqChatCompletion:
        self.calls.append({"model": model, "messages": messages})
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


def create_destination(client, headers: dict[str, str] | None = None) -> dict:
    response = client.post(
        "/api/v1/destinations",
        headers=headers or admin_headers(client),
        json=DESTINATION_PAYLOAD,
    )

    assert response.status_code == 201

    return response.json()


def create_accommodation(
    client,
    *,
    destination_id: int,
    headers: dict[str, str],
) -> dict:
    response = client.post(
        f"/api/v1/destinations/{destination_id}/accommodations",
        headers=headers,
        json={
            "name": "AI Beach Stay",
            "room_type": "Standard Room",
            "price": "1800.00",
            "capacity": 2,
        },
    )

    assert response.status_code == 201

    return response.json()


def create_transportation(
    client,
    *,
    destination_id: int,
    headers: dict[str, str],
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
                "estimated_total_cost": "4500.00",
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
    assert [run["model_id"] for run in body["model_runs"]] == [
        "compare-a-model",
        "compare-b-model",
        "compare-c-model",
    ]
