import json

from app.integrations.groq.client import get_groq_client
from app.features.ai import service as ai_service_module
from app.features.ai.rag import RagMatch
from tests.test_phase5_ai_itineraries import (
    FakeGroqClient,
    admin_headers,
    configure_ai,
    create_destination,
    user_headers,
)


def planning_state(destination_id: int) -> dict:
    return {
        "origin": {"label": "Davao City"},
        "destination_ids": [destination_id],
        "total_budget": "5000.00",
        "budget_scope": "whole_trip",
        "traveler_count": 2,
        "day_count": 3,
        "night_count": 2,
        "return_to_origin": True,
        "interests": ["beach"],
        "selected_transport_option_ids": ["mode:personal_vehicle"],
    }


def test_planning_chat_applies_explicit_updates_and_returns_revision_preview(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    fake_client = FakeGroqClient([
        json.dumps(
            {
                "chat_response": "I updated the plan for a solo day trip.",
                "state_updates": {
                    "traveler_count": 1,
                    "day_count": 1,
                    "night_count": 0,
                    "total_budget": "6000.00",
                },
            },
        ),
    ])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Make it a solo day trip with a 6000 peso budget.",
            "use_rag": False,
            "input_revision": 12,
            "planning_state": planning_state(destination["destination_id"]),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["chat_response"] == "I updated the plan for a solo day trip."
    assert body["planning"]["input_revision"] == 12
    assert body["planning"]["update_status"] == "applied"
    assert body["planning"]["state_updates"] == {
        "traveler_count": 1,
        "day_count": 1,
        "night_count": 0,
        "total_budget": "6000.00",
    }
    preview = body["planning"]["preview"]
    assert preview["input_revision"] == 12
    assert preview["whole_trip_budget"] == "6000.00"
    assert preview["state"]["destination_ids"] == [destination["destination_id"]]
    assert preview["state"]["origin"] == {"label": "Davao City", "lat": None, "lng": None}
    assert preview["state"]["traveler_count"] == 1
    assert preview["state"]["day_count"] == 1
    assert preview["state"]["night_count"] == 0
    assert preview["state"]["selected_transport_option_ids"] == ["mode:personal_vehicle"]
    assert preview["accommodation_options"] == []

    prompt_payload = json.loads(fake_client.calls[0]["messages"][-1]["content"])
    assert prompt_payload["input_revision"] == 12
    assert prompt_payload["planning_state"]["destination_ids"] == [destination["destination_id"]]


def test_planning_chat_rejects_destination_ids_outside_catalog_context(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    fake_client = FakeGroqClient([
        json.dumps(
            {
                "chat_response": "I found that destination.",
                "state_updates": {"destination_ids": [999999]},
            },
        ),
    ])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Change the destination.",
            "use_rag": False,
            "planning_state": planning_state(destination["destination_id"]),
        },
    )

    assert response.status_code == 200
    planning = response.json()["planning"]
    assert planning["update_status"] == "needs_clarification"
    assert planning["state_updates"] == {}
    assert planning["preview"]["state"]["destination_ids"] == [destination["destination_id"]]
    assert "kept your current destination selection" in response.json()["chat_response"]


def test_planning_chat_accepts_destination_id_from_retrieved_catalog_context(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    current_destination = create_destination(client, headers=admin, name="Current Beach")
    new_destination = create_destination(client, headers=admin, name="Matched Beach")

    async def retrieve_match(self, query, *, limit=6, history=None, context=None):
        self.coverage = {
            "status": "matched",
            "destinations": [],
            "truncated": False,
        }
        return [
            RagMatch(
                source="destination",
                source_id=new_destination["destination_id"],
                title="Matched Beach",
                score=1.0,
                payload={"destination_id": new_destination["destination_id"]},
            ),
        ]

    monkeypatch.setattr(ai_service_module.VectorRAGRetriever, "retrieve", retrieve_match)
    fake_client = FakeGroqClient([
        json.dumps(
            {
                "chat_response": "I matched the new destination in the catalog.",
                "state_updates": {"destination_ids": [new_destination["destination_id"]]},
            },
        ),
    ])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Change to Matched Beach.",
            "planning_state": planning_state(current_destination["destination_id"]),
        },
    )

    assert response.status_code == 200
    planning = response.json()["planning"]
    assert planning["update_status"] == "applied"
    assert planning["state_updates"] == {
        "destination_ids": [new_destination["destination_id"]],
    }
    assert planning["preview"]["state"]["destination_ids"] == [
        new_destination["destination_id"],
    ]


def test_planning_chat_origin_label_update_clears_stale_coordinates(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    state = planning_state(destination["destination_id"])
    state["origin"] = {"label": "Davao City", "lat": 7.0731, "lng": 125.6128}
    fake_client = FakeGroqClient([
        json.dumps(
            {
                "chat_response": "I changed the starting point to Mati City.",
                "state_updates": {"origin": {"label": "Mati City"}},
            },
        ),
    ])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Start from Mati City instead.",
            "use_rag": False,
            "planning_state": state,
        },
    )

    assert response.status_code == 200
    preview_origin = response.json()["planning"]["preview"]["state"]["origin"]
    assert preview_origin == {"label": "Mati City", "lat": None, "lng": None}


def test_planning_chat_invalid_structured_output_keeps_current_preview(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    fake_client = FakeGroqClient(["This is not the required JSON object."])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Make it one day.",
            "use_rag": False,
            "input_revision": 3,
            "planning_state": planning_state(destination["destination_id"]),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["planning"]["update_status"] == "invalid_output"
    assert body["planning"]["state_updates"] == {}
    assert body["planning"]["preview"]["input_revision"] == 3
    assert body["planning"]["preview"]["state"]["day_count"] == 3
    assert body["planning"]["preview"]["state"]["destination_ids"] == [
        destination["destination_id"],
    ]


def test_planning_chat_rejects_model_changes_to_preview_selections(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    fake_client = FakeGroqClient([
        json.dumps(
            {
                "chat_response": "I chose the transport for you.",
                "state_updates": {"selected_transport_option_ids": []},
            },
        ),
    ])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Make it cheaper.",
            "use_rag": False,
            "planning_state": planning_state(destination["destination_id"]),
        },
    )

    assert response.status_code == 200
    planning = response.json()["planning"]
    assert planning["update_status"] == "invalid_output"
    assert planning["state_updates"] == {}
    assert planning["preview"]["state"]["selected_transport_option_ids"] == [
        "mode:personal_vehicle",
    ]
