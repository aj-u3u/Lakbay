import json

import pytest

from app.integrations.groq.client import get_groq_client
from app.integrations.osrm.errors import OSRMRouteNotFoundError
from app.integrations.osrm.schemas import (
    OSRMLeg,
    OSRMRouteResult,
    OSRMTableEntry,
    OSRMTableResult,
)
from app.features.ai import service as ai_service_module
from app.features.ai import router as ai_router_module
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


class CandidateOSRM:
    def __init__(self, *, unreachable_lats: set[float] | None = None) -> None:
        self.unreachable_lats = unreachable_lats or set()
        self.calls = 0

    async def preview_route(self, *, travel_mode, coordinates):
        self.calls += 1
        if coordinates[-1].lat in self.unreachable_lats:
            raise OSRMRouteNotFoundError("No road route reaches this arrival point.")
        return OSRMRouteResult(
            total_distance_meters=12000,
            total_duration_seconds=1200,
            legs=[OSRMLeg(distance_meters=12000, duration_seconds=1200)],
        )

    async def table(self, *, travel_mode, origin, destinations):
        self.calls += 1
        return OSRMTableResult(
            source_snap_meters=5.0,
            entries=[
                OSRMTableEntry(duration_seconds=None, distance_meters=None, snap_meters=5.0)
                if point.lat in self.unreachable_lats
                else OSRMTableEntry(duration_seconds=1200, distance_meters=12000, snap_meters=5.0)
                for point in destinations
            ],
        )


def verified_arrival(index: int) -> dict:
    return {
        "arrival_lat": 6.95 + index * 0.001,
        "arrival_lng": 126.25,
        "arrival_source_url": "https://example.org/visitor-gate",
        "arrival_verified_at": "2026-10-29T00:00:00Z",
        "route_ready": True,
    }


def test_planning_chat_returns_grounded_candidates_without_saving_preferences(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    beaches = [
        create_destination(
            client, headers=admin, name=f"Beach {index}", **verified_arrival(index),
        )
        for index in range(6)
    ]
    create_destination(
        client,
        headers=admin,
        name="Mountain Trail",
        category="mountain",
        vibes="adventure",
        activities="hiking",
    )
    fake_client = FakeGroqClient([
        json.dumps({
            "chat_response": "I found beach matches in the catalog.",
            "state_updates": {"interests": ["beach"]},
        }),
    ])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client
    osrm = CandidateOSRM()
    monkeypatch.setattr(ai_router_module, "get_osrm_client", lambda: osrm)
    traveler = user_headers(client)

    response = client.post(
        "/api/v1/ai/chat",
        headers=traveler,
        json={
            "message": "Suggest beaches for me.",
            "use_rag": False,
            "input_revision": 4,
            "planning_state": {
                "origin": {"label": "Davao City", "lat": 7.0731, "lng": 125.6128},
                "destination_ids": [],
                "interests": [],
                "traveler_count": 2,
                "selected_transport_option_ids": ["mode:personal_vehicle"],
            },
        },
    )

    assert response.status_code == 200
    planning = response.json()["planning"]
    assert planning["input_revision"] == 4
    assert planning["recommendation_total_candidates"] == 6
    assert len(planning["recommendations"]) == 5
    assert {item["destination_id"] for item in planning["recommendations"]} == {
        beach["destination_id"] for beach in beaches[:5]
    }
    assert all("category" in item["matched_fields"] for item in planning["recommendations"])
    assert all(item["route_provider"] == "osrm" for item in planning["recommendations"])
    assert all(item["route_verified"] for item in planning["recommendations"])
    assert all(item["travel_basis"] == "road_route" for item in planning["recommendations"])
    assert all(item["route_distance_km"] == "12.00" for item in planning["recommendations"])
    assert all(item["route_duration_minutes"] == 20 for item in planning["recommendations"])
    assert all(0 <= item["score"] <= 100 for item in planning["recommendations"])
    assert planning["recommendation_shortfall_reason"] is None
    # One travel-time table request covers every candidate.
    assert osrm.calls == 1
    assert client.get(
        "/api/v1/recommendations/preferences/latest",
        headers=traveler,
    ).status_code == 404


def test_planning_chat_puts_verified_routes_first_and_explains_skipped_places(
    client, monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    unverified = create_destination(client, headers=admin, name="Beach Unverified")
    create_destination(client, headers=admin, name="Beach Ferry", how_to_get_there="By ferry", **verified_arrival(1))
    create_destination(client, headers=admin, name="Beach No Route", **verified_arrival(2))
    reachable = create_destination(client, headers=admin, name="Beach Reachable", **verified_arrival(3))
    create_destination(client, headers=admin, name="Mountain", category="mountain", vibes="adventure", activities="hiking")
    osrm = CandidateOSRM(unreachable_lats={verified_arrival(2)["arrival_lat"]})
    monkeypatch.setattr(ai_router_module, "get_osrm_client", lambda: osrm)
    client.app.dependency_overrides[get_groq_client] = lambda: FakeGroqClient([
        json.dumps({"chat_response": "Beach choices.", "state_updates": {"interests": ["beach"]}}),
    ])

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Find beaches.", "use_rag": False,
            "planning_state": {
                "origin": {"label": "Davao City", "lat": 7.0731, "lng": 125.6128},
                "selected_transport_option_ids": ["mode:personal_vehicle"],
            },
        },
    )

    assert response.status_code == 200
    planning = response.json()["planning"]
    # The verified road route comes first; the unverified place fills the next
    # slot with an approximate label instead of being hidden.
    assert [item["destination_id"] for item in planning["recommendations"]] == [
        reachable["destination_id"], unverified["destination_id"],
    ]
    assert [item["route_verified"] for item in planning["recommendations"]] == [True, False]
    assert planning["recommendations"][1]["travel_basis"] == "approximate_location"
    assert planning["recommendation_total_candidates"] == 2
    assert planning["recommendation_shortfall_reason"] == (
        "Only 2 places qualify for your Top 5: 1 does not match your interests, "
        "1 needs a boat or ferry and 1 has no road route from your start."
    )
    assert response.json()["chat_response"] == planning["recommendation_shortfall_reason"]
    assert osrm.calls == 1


def test_planning_chat_does_not_fill_empty_preference_match(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    create_destination(
        client, headers=admin_headers(client), name="Mountain", category="mountain",
        vibes="adventure", activities="hiking", **verified_arrival(0),
    )
    osrm = CandidateOSRM()
    monkeypatch.setattr(ai_router_module, "get_osrm_client", lambda: osrm)
    client.app.dependency_overrides[get_groq_client] = lambda: FakeGroqClient([
        json.dumps({"chat_response": "I found beaches.", "state_updates": {"interests": ["beach"]}}),
    ])

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Find beaches.", "use_rag": False,
            "planning_state": {
                "origin": {"label": "Davao City", "lat": 7.0731, "lng": 125.6128},
                "selected_transport_option_ids": ["mode:personal_vehicle"],
            },
        },
    )

    planning = response.json()["planning"]
    assert planning["recommendations"] == []
    assert planning["recommendation_total_candidates"] == 0
    assert "No active catalog destination matches" in planning["recommendation_shortfall_reason"]
    assert osrm.calls == 0


def test_planning_chat_without_map_origin_never_claims_a_road_route(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    beach = create_destination(client, headers=admin_headers(client), **verified_arrival(0))
    client.app.dependency_overrides[get_groq_client] = lambda: FakeGroqClient([
        json.dumps({"chat_response": "I found a beach.", "state_updates": {"interests": ["beach"]}}),
    ])

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Find beaches.", "use_rag": False,
            "planning_state": {
                "origin": {"label": "Davao City"},
                "selected_transport_option_ids": ["mode:personal_vehicle"],
            },
        },
    )

    planning = response.json()["planning"]
    [item] = planning["recommendations"]
    assert item["destination_id"] == beach["destination_id"]
    assert item["route_verified"] is False
    assert item["travel_basis"] == "unknown"
    assert item["route_duration_minutes"] is None
    assert "Set a start point to rank by travel time." in item["reasons"]
    assert planning["recommendation_shortfall_reason"] == "Only 1 place qualifies for your Top 5."
    assert response.json()["chat_response"] == planning["recommendation_shortfall_reason"]


def test_planning_chat_shows_unverified_matches_with_a_label(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    beach = create_destination(client, headers=admin_headers(client), name="Beach Without Gate")
    client.app.dependency_overrides[get_groq_client] = lambda: FakeGroqClient([
        json.dumps({"chat_response": "I found a beach.", "state_updates": {"interests": ["beach"]}}),
    ])

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={"message": "Find beaches.", "use_rag": False, "planning_state": {}},
    )

    planning = response.json()["planning"]
    [item] = planning["recommendations"]
    assert item["destination_id"] == beach["destination_id"]
    assert item["route_verified"] is False
    assert planning["recommendation_total_candidates"] == 1


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

    previous_state = planning_state(current_destination["destination_id"])
    previous_state["adult_count"] = 1
    previous_state["child_ages"] = [8]
    previous_state["age_pricing_rules"] = [
        {
            "category": "destination",
            "reference_id": f"destination:{current_destination['destination_id']}",
            "adult_unit_amount": "200.00",
            "child_bands": [{"min_age": 8, "max_age": 8, "rate": "half"}],
        },
    ]
    previous_state["cost_allowances"] = [
        {
            "category": "destination",
            "destination_id": current_destination["destination_id"],
            "amount": "200.00",
        },
    ]

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Change to Matched Beach.",
            "planning_state": previous_state,
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
    assert planning["preview"]["state"]["selected_transport_option_ids"] == []
    assert planning["preview"]["state"]["cost_allowances"] == []
    assert planning["preview"]["state"]["age_pricing_rules"] == []
    assert planning["preview"]["state"]["child_ages"] == [8]


def test_planning_chat_origin_label_update_clears_stale_coordinates_and_road_confirmation(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    state = planning_state(destination["destination_id"])
    state["origin"] = {"label": "Davao City", "lat": 7.0731, "lng": 125.6128}
    state["route_preferences"] = {"road_access_confirmed": True}
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
    planning = response.json()["planning"]
    preview_state = planning["preview"]["state"]
    assert preview_state["origin"] == {"label": "Mati City", "lat": None, "lng": None}
    assert preview_state["route_preferences"] is None
    assert planning["state_updates"]["route_preferences"] is None


def test_planning_chat_recovers_valid_fields_when_origin_has_wrong_shape(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    fake_client = FakeGroqClient([json.dumps({
        "chat_response": "I saved the new origin and your full plan.",
        "state_updates": {
            "origin": "Mati City",
            "total_budget": 6000,
            "traveler_count": 1,
            "day_count": 2,
        },
    })])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Start from Mati City, make it a two-day solo trip for 6000 pesos.",
            "use_rag": False,
            "planning_state": planning_state(destination["destination_id"]),
        },
    )

    assert response.status_code == 200
    body = response.json()
    planning = body["planning"]
    assert planning["update_status"] == "applied"
    assert planning["state_updates"] == {
        "total_budget": "6000",
        "traveler_count": 1,
        "day_count": 2,
    }
    state = planning["preview"]["state"]
    assert state["origin"] == {"label": "Davao City", "lat": None, "lng": None}
    assert state["total_budget"] == "6000"
    assert state["traveler_count"] == 1
    assert state["day_count"] == 2
    assert "could not use the starting place" in body["chat_response"]
    assert "I saved the new origin" not in body["chat_response"]
    prompt = fake_client.calls[0]["messages"][0]["content"]
    assert '{"origin":{"label":"Davao City"}}' in prompt
    assert "Never infer night_count from day_count alone" in prompt


def test_planning_chat_recovers_budget_but_rejects_bad_destination_field(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    fake_client = FakeGroqClient([json.dumps({
        "chat_response": "I chose a different destination.",
        "state_updates": {
            "destination_ids": ["not-an-id"],
            "total_budget": 7000,
        },
    })])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Try somewhere else, with a 7000 peso budget.",
            "use_rag": False,
            "planning_state": planning_state(destination["destination_id"]),
        },
    )

    assert response.status_code == 200
    planning = response.json()["planning"]
    assert planning["update_status"] == "applied"
    assert planning["state_updates"] == {"total_budget": "7000"}
    assert planning["preview"]["state"]["destination_ids"] == [
        destination["destination_id"],
    ]
    assert "could not use the destination" in response.json()["chat_response"]


def test_planning_chat_rejects_inferred_night_and_return_details(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    state = planning_state(destination["destination_id"])
    state.pop("night_count")
    state.pop("return_to_origin")
    fake_client = FakeGroqClient([json.dumps({
        "chat_response": "I set one night and a return trip.",
        "state_updates": {
            "total_budget": 6000,
            "night_count": 1,
            "return_to_origin": True,
        },
    })])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Plan a two-day solo trip for 6000 pesos.",
            "use_rag": False,
            "planning_state": state,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["planning"]["update_status"] == "applied"
    assert body["planning"]["state_updates"] == {"total_budget": "6000"}
    next_state = body["planning"]["preview"]["state"]
    assert next_state["night_count"] is None
    assert next_state["return_to_origin"] is None
    assert "overnight stay" in body["chat_response"]
    assert "return trip" in body["chat_response"]
    assert "I set one night" not in body["chat_response"]


@pytest.mark.parametrize(
    ("message", "night_count", "return_to_origin"),
    [
        ("Make it two days, one night, and a round trip.", 1, True),
        ("Make it a day trip, one way.", 0, False),
        ("We are not staying overnight and not returning to Davao City.", 0, False),
    ],
)
def test_planning_chat_accepts_explicit_night_and_return_details(
    client,
    monkeypatch,
    message,
    night_count,
    return_to_origin,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    state = planning_state(destination["destination_id"])
    state.pop("night_count")
    state.pop("return_to_origin")
    fake_client = FakeGroqClient([json.dumps({
        "chat_response": "I updated those trip details.",
        "state_updates": {
            "night_count": night_count,
            "return_to_origin": return_to_origin,
        },
    })])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": message,
            "use_rag": False,
            "planning_state": state,
        },
    )

    assert response.status_code == 200
    assert response.json()["planning"]["state_updates"] == {
        "night_count": night_count,
        "return_to_origin": return_to_origin,
    }


def test_planning_chat_does_not_warn_when_model_repeats_existing_trip_details(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    fake_client = FakeGroqClient([json.dumps({
        "chat_response": "What else would you like to change?",
        "state_updates": {"night_count": 2, "return_to_origin": True},
    })])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "What activities are nearby?",
            "use_rag": False,
            "planning_state": planning_state(destination["destination_id"]),
        },
    )

    assert response.status_code == 200
    assert response.json()["planning"]["update_status"] == "no_changes"
    assert response.json()["chat_response"] == "What else would you like to change?"


def test_planning_chat_does_not_choose_between_ambiguous_trip_details(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    state = planning_state(destination["destination_id"])
    state.pop("night_count")
    state.pop("return_to_origin")
    fake_client = FakeGroqClient([json.dumps({
        "chat_response": "I chose one night and a return trip.",
        "state_updates": {"night_count": 1, "return_to_origin": True},
    })])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Maybe one night or two nights, and round trip or one way.",
            "use_rag": False,
            "planning_state": state,
        },
    )

    assert response.status_code == 200
    assert response.json()["planning"]["state_updates"] == {}
    assert response.json()["planning"]["preview"]["state"]["night_count"] is None
    assert response.json()["planning"]["preview"]["state"]["return_to_origin"] is None
    assert "I chose one night" not in response.json()["chat_response"]


def test_planning_chat_rejects_model_echo_when_traveler_changes_nights(
    client,
    monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    fake_client = FakeGroqClient([json.dumps({
        "chat_response": "I changed it to one night.",
        "state_updates": {"night_count": 2},
    })])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Change to one night.",
            "use_rag": False,
            "planning_state": planning_state(destination["destination_id"]),
        },
    )

    assert response.status_code == 200
    assert response.json()["planning"]["state_updates"] == {}
    assert response.json()["planning"]["preview"]["state"]["night_count"] == 2
    assert "I changed it to one night" not in response.json()["chat_response"]


@pytest.mark.parametrize(
    ("message", "question", "updates"),
    [
        ("one", "How many nights will you stay?", {"night_count": 1}),
        ("yes", "Will you return to Davao City?", {"return_to_origin": True}),
    ],
)
def test_planning_chat_accepts_short_answers_to_specific_questions(
    client,
    monkeypatch,
    message,
    question,
    updates,
) -> None:
    configure_ai(monkeypatch)
    destination = create_destination(client, headers=admin_headers(client))
    state = planning_state(destination["destination_id"])
    state.pop("night_count")
    state.pop("return_to_origin")
    fake_client = FakeGroqClient([json.dumps({
        "chat_response": "I added that detail.",
        "state_updates": updates,
    })])
    client.app.dependency_overrides[get_groq_client] = lambda: fake_client

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": message,
            "history": [{"role": "assistant", "content": question}],
            "use_rag": False,
            "planning_state": state,
        },
    )

    assert response.status_code == 200
    assert response.json()["planning"]["state_updates"] == updates


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
                "state_updates": {
                    "selected_transport_option_ids": [],
                    "total_budget": 7000,
                },
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
    assert planning["preview"]["state"]["total_budget"] == "5000.00"


def _named_place_chat(client, message, reply):
    admin = admin_headers(client)
    samal = create_destination(
        client, headers=admin, name="Samal Island Beach", location="Samal Island",
        district="Davao del Norte", **verified_arrival(0),
    )
    samal_two = create_destination(
        client, headers=admin, name="Samal Pearl Farm", location="Samal Island",
        district="Davao del Norte", **verified_arrival(2),
    )
    create_destination(
        client, headers=admin, name="Mati Rock Beach", location="Mati City",
        district="Davao Oriental", **verified_arrival(1),
    )
    client.app.dependency_overrides[get_groq_client] = lambda: FakeGroqClient([
        json.dumps({"chat_response": reply, "state_updates": {}}),
    ])
    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": message,
            "use_rag": True,
            "planning_state": {"origin": {"label": "Davao City"}},
        },
    )
    assert response.status_code == 200
    return (samal, samal_two), response.json()


def test_named_place_without_interests_offers_selectable_cards(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    (samal, samal_two), body = _named_place_chat(
        client, "I want to go to Samal Island", "Samal has a few spots.",
    )

    planning = body["planning"]
    # Two Samal places match equally, so nothing is guessed: the traveler gets cards.
    assert planning["state_updates"] == {}
    assert {item["destination_id"] for item in planning["recommendations"]} == {
        samal["destination_id"], samal_two["destination_id"],
    }
    assert planning["recommendation_total_candidates"] == 2
    assert planning["recommendation_shortfall_reason"] is None
    # The model's own reply is kept, not replaced by a ranking message.
    assert body["chat_response"] == "Samal has a few spots."


def test_greeting_without_a_named_place_offers_no_cards(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    _, body = _named_place_chat(client, "hello there", "Hi! Where would you like to go?")

    planning = body["planning"]
    assert planning["recommendations"] == []
    assert planning["recommendation_shortfall_reason"] == (
        "No travel interests were supplied, so there is no preference match to rank."
    )


def test_interest_detected_in_the_message_ranks_when_model_omits_it(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    beach = create_destination(client, headers=admin, name="Beach One", **verified_arrival(0))
    create_destination(
        client, headers=admin, name="Mountain", category="mountain",
        vibes="adventure", activities="hiking", **verified_arrival(1),
    )
    monkeypatch.setattr(ai_router_module, "get_osrm_client", lambda: CandidateOSRM())
    client.app.dependency_overrides[get_groq_client] = lambda: FakeGroqClient([
        # The model forgot to record the interest the traveler stated.
        json.dumps({"chat_response": "Here are some ideas.", "state_updates": {}}),
    ])

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "Find me beaches in Davao",
            "use_rag": True,
            "planning_state": {
                "origin": {"label": "Davao City", "lat": 7.0731, "lng": 125.6128},
                "selected_transport_option_ids": ["mode:personal_vehicle"],
            },
        },
    )

    assert response.status_code == 200, response.text
    planning = response.json()["planning"]
    assert [item["destination_id"] for item in planning["recommendations"]] == [
        beach["destination_id"],
    ]
    assert planning["state_updates"] == {}  # the saved plan is not changed by the fallback


def _named_chat(client, message, *, destinations, model_reply, planning_state=None):
    admin = admin_headers(client)
    created = {
        name: create_destination(client, headers=admin, name=name, **verified_arrival(i))
        for i, name in enumerate(destinations)
    }
    client.app.dependency_overrides[get_groq_client] = lambda: FakeGroqClient([model_reply])
    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": message,
            "use_rag": True,
            "planning_state": planning_state or {"origin": {"label": "Davao City"}},
        },
    )
    assert response.status_code == 200, response.text
    return created, response.json()


CAUTIOUS_REPLY = json.dumps({
    "chat_response": "Great choice! Where will you start, and how many travelers?",
    "state_updates": {},
})


def test_a_named_destination_is_added_even_when_the_model_only_asks_questions(
    client, monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    created, body = _named_chat(
        client, "I like to go to bemwa",
        destinations=["Bemwa Farm", "Mati Rock Beach"], model_reply=CAUTIOUS_REPLY,
    )

    farm_id = created["Bemwa Farm"]["destination_id"]
    planning = body["planning"]
    assert planning["state_updates"] == {"destination_ids": [farm_id]}
    assert planning["update_status"] == "applied"
    assert [d["name"] for d in planning["preview"]["destinations"]] == ["Bemwa Farm"]
    assert body["chat_response"].startswith("Great choice! Where will you start")
    assert body["chat_response"].endswith("I added Bemwa Farm to your plan.")
    assert planning["recommendations"] == []  # nothing left to choose


def test_a_named_destination_is_added_even_when_the_model_output_is_unusable(
    client, monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    created, body = _named_chat(
        client, "I like to go to bemwa",
        destinations=["Bemwa Farm"], model_reply="Sorry, this is not JSON at all.",
    )

    planning = body["planning"]
    assert planning["state_updates"] == {
        "destination_ids": [created["Bemwa Farm"]["destination_id"]],
    }
    assert planning["update_status"] == "applied"
    assert "I added Bemwa Farm to your plan." in body["chat_response"]


def test_equally_good_matches_become_cards_instead_of_a_guess(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    created, body = _named_chat(
        client, "I want to see Uraya",
        destinations=["Uraya's Peak Adventure Park", "Uraya Falls", "Mati Rock Beach"],
        model_reply=CAUTIOUS_REPLY,
    )

    planning = body["planning"]
    assert planning["state_updates"] == {}
    assert {item["destination_id"] for item in planning["recommendations"]} == {
        created["Uraya's Peak Adventure Park"]["destination_id"],
        created["Uraya Falls"]["destination_id"],
    }
    assert "I added" not in body["chat_response"]


def test_a_negated_request_neither_adds_nor_offers_the_place(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    _, body = _named_chat(
        client, "I don't want to go to bemwa",
        destinations=["Bemwa Farm"], model_reply=CAUTIOUS_REPLY,
    )

    planning = body["planning"]
    assert planning["state_updates"] == {}
    assert planning["recommendations"] == []
    assert "I added" not in body["chat_response"]


def test_an_already_chosen_destination_is_not_replaced_by_a_mention(
    client, monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    chosen = create_destination(client, headers=admin, name="Eden Nature Park", **verified_arrival(0))
    create_destination(client, headers=admin, name="Bemwa Farm", **verified_arrival(1))
    client.app.dependency_overrides[get_groq_client] = lambda: FakeGroqClient([CAUTIOUS_REPLY])

    response = client.post(
        "/api/v1/ai/chat",
        headers=user_headers(client),
        json={
            "message": "What about bemwa?",
            "use_rag": True,
            "planning_state": {
                "origin": {"label": "Davao City"},
                "destination_ids": [chosen["destination_id"]],
            },
        },
    )

    assert response.status_code == 200, response.text
    planning = response.json()["planning"]
    assert planning["state_updates"] == {}
    assert [d["name"] for d in planning["preview"]["destinations"]] == ["Eden Nature Park"]


def test_double_escaped_line_breaks_in_the_reply_become_real_line_breaks(
    client, monkeypatch,
) -> None:
    configure_ai(monkeypatch)
    _, body = _named_chat(
        client, "hello there", destinations=["Bemwa Farm"],
        model_reply=json.dumps({
            # A literal backslash followed by "n", as some models emit it.
            "chat_response": "Great!\\n- Where from?\\n- How many travelers?",
            "state_updates": {},
        }),
    )

    assert body["chat_response"] == "Great!\n- Where from?\n- How many travelers?"
    assert "\\n" not in body["chat_response"]
