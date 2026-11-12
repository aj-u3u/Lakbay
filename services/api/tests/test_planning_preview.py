import pytest
from sqlalchemy import event
from sqlalchemy.engine import Engine

from app.integrations.google_routes.client import get_google_routes_client
from app.integrations.groq.client import get_groq_client
from app.integrations.osrm.client import get_osrm_client


DESTINATION_PAYLOAD = {
    "name": "Planning Test Beach",
    "district": "Davao del Norte",
    "location": "Panabo City",
    "category": "beach",
    "activities": "swimming, photography",
    "lat": 7.3086,
    "lng": 125.6832,
    "estimated_cost": "0.00",
    "entrance_fee": "Contact provider for current fees.",
}


def register(client, *, admin: bool = False) -> dict[str, str]:
    payload = {
        "full_name": "Planning Admin" if admin else "Planning Traveler",
        "email": "planning-admin@example.com" if admin else "planning@example.com",
        "password": "password123",
        "confirm_password": "password123",
    }
    path = "/api/v1/auth/register"
    if admin:
        path += "/admin"
        payload["admin_registration_code"] = "admin-test-code"
    response = client.post(path, json=payload)
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def create_destination(client, headers, **overrides) -> dict:
    response = client.post(
        "/api/v1/destinations",
        headers=headers,
        json={**DESTINATION_PAYLOAD, **overrides},
    )
    assert response.status_code == 201
    return response.json()


def create_transportation(client, headers, destination_id: int, **overrides) -> dict:
    response = client.post(
        f"/api/v1/destinations/{destination_id}/transportations",
        headers=headers,
        json={
            "vehicle_type": "Bus",
            "transport_mode": "public_transport",
            "route_from": "Davao City",
            "route_to": "Panabo City",
            "price": "120.00",
            "duration_minutes": 60,
            **overrides,
        },
    )
    assert response.status_code == 201
    return response.json()


def preview_request(destination_id: int, **state_overrides) -> dict:
    return {
        "input_revision": 7,
        "state": {
            "origin": {"label": "Davao City", "lat": 7.07, "lng": 125.61},
            "destination_ids": [destination_id],
            "total_budget": "15000.00",
            "budget_scope": "whole_trip",
            "traveler_count": 1,
            "day_count": 1,
            "night_count": 0,
            "return_to_origin": True,
            "interests": ["coffee"],
            "reserve_amount": "500.00",
            "selected_transport_option_ids": [],
            "selected_activity_option_ids": [],
            **state_overrides,
        },
    }


def test_planning_preview_requires_authentication(client) -> None:
    response = client.post("/api/v1/planning/preview", json={})

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_planning_preview_preserves_state_and_revision_between_selections(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    transportation = create_transportation(client, admin, destination["destination_id"])
    user = register(client)
    request = preview_request(destination["destination_id"])

    first = client.post("/api/v1/planning/preview", headers=user, json=request)

    assert first.status_code == 200
    first_body = first.json()
    assert first_body["input_revision"] == request["input_revision"]
    assert {key: first_body["state"][key] for key in request["state"]} == request["state"]
    assert first_body["whole_trip_budget"] == "15000.00"
    assert first_body["status"] == "choices_available"
    assert first_body["missing_inputs"] == []
    assert first_body["selection_problems"] == []
    assert first_body["budget"]["completeness"] == "partial"
    assert first_body["budget"]["total_estimate"] is None
    assert first_body["route"]["status"] == "not_requested"
    assert first_body["route"]["summary"] is None
    activity_id = first_body["activity_options"][0]["option_id"]
    updated_state = {
        **first_body["state"],
        "selected_transport_option_ids": [
            f"transportation:{transportation['transportation_id']}"
        ],
        "selected_activity_option_ids": [activity_id],
    }

    second = client.post(
        "/api/v1/planning/preview",
        headers=user,
        json={"input_revision": 8, "state": updated_state},
    )

    assert second.status_code == 200
    assert second.json()["input_revision"] == 8
    assert second.json()["state"] == updated_state
    assert second.json()["selection_problems"] == []
    assert next(
        item for item in second.json()["transport_options"]
        if item["option_id"] == updated_state["selected_transport_option_ids"][0]
    )["selected"] is True
    assert next(
        item for item in second.json()["activity_options"] if item["option_id"] == activity_id
    )["selected"] is True
    assert {
        item["option_id"] for item in second.json()["activity_options"] if item["selected"]
    } == {activity_id}
    assert {
        item["option_id"] for item in second.json()["transport_options"] if item["selected"]
    } == {f"transportation:{transportation['transportation_id']}"}
    assert {
        item["option_id"] for item in second.json()["activity_options"]
    } == {item["option_id"] for item in first_body["activity_options"]}


def test_planning_preview_keeps_partial_state_and_identifies_missing_details(client) -> None:
    user = register(client)

    response = client.post(
        "/api/v1/planning/preview",
        headers=user,
        json={"input_revision": 2, "state": {"origin": {"label": "Davao City"}}},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["input_revision"] == 2
    assert body["state"]["origin"]["label"] == "Davao City"
    assert body["status"] == "needs_details"
    assert body["whole_trip_budget"] is None
    assert {
        "origin.coordinates",
        "destination_ids",
        "total_budget",
        "traveler_count",
        "day_count",
        "night_count",
        "return_to_origin",
    }.issubset(set(body["missing_inputs"]))
    assert body["state"]["night_count"] is None
    assert body["state"]["return_to_origin"] is None
    assert body["destinations"] == []
    assert body["activity_options"] == []


def test_planning_preview_converts_only_explicit_per_person_budget(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    user = register(client)

    response = client.post(
        "/api/v1/planning/preview",
        headers=user,
        json=preview_request(
            destination["destination_id"],
            budget_scope="per_person",
            total_budget="3000.00",
            traveler_count=3,
        ),
    )

    assert response.status_code == 200
    assert response.json()["state"]["total_budget"] == "3000.00"
    assert response.json()["state"]["budget_scope"] == "per_person"
    assert response.json()["whole_trip_budget"] == "9000.00"
    repeated = client.post(
        "/api/v1/planning/preview", headers=user,
        json={"state": response.json()["state"]},
    )
    assert repeated.status_code == 200
    assert repeated.json()["whole_trip_budget"] == "9000.00"


def test_planning_preview_matches_route_direction_without_claiming_full_journey(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    outbound = create_transportation(
        client,
        admin,
        destination["destination_id"],
        route_to=destination["name"],
    )
    inbound = create_transportation(
        client,
        admin,
        destination["destination_id"],
        route_from=destination["name"],
        route_to="Davao City",
    )
    local = create_transportation(
        client,
        admin,
        destination["destination_id"],
        route_from="Panabo City Terminal",
        route_to="Panabo City Seawall",
        vehicle_type="Tricycle",
    )
    city_only = create_transportation(client, admin, destination["destination_id"])
    user = register(client)

    response = client.post(
        "/api/v1/planning/preview",
        headers=user,
        json=preview_request(destination["destination_id"]),
    )

    assert response.status_code == 200
    options = {item["option_id"]: item for item in response.json()["transport_options"]}
    expected_matches = {
        outbound["transportation_id"]: "origin_to_destination",
        inbound["transportation_id"]: "destination_to_origin",
        local["transportation_id"]: "unconfirmed",
        city_only["transportation_id"]: "unconfirmed",
    }
    for transportation_id, expected_match in expected_matches.items():
        option = options[f"transportation:{transportation_id}"]
        assert option["route_match"] == expected_match
        assert option["journey_complete"] is False
        assert option["price_basis"] is None
        assert option["listed_price"] == "120.00"
        assert "fare_basis" in option["missing_information"]
    personal_vehicle = options["mode:personal_vehicle"]
    assert personal_vehicle["listed_price"] is None
    assert personal_vehicle["journey_complete"] is False


def test_planning_preview_uses_catalog_activities_with_stable_ids_and_unknown_fees(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(
        client,
        admin,
        activities="Swimming; Photography\nBeach walking",
        estimated_cost="0.00",
        entrance_fee="0",
    )
    user = register(client)
    request = preview_request(destination["destination_id"], interests=["coffee"])

    first = client.post("/api/v1/planning/preview", headers=user, json=request)
    second = client.post("/api/v1/planning/preview", headers=user, json=request)

    assert first.status_code == second.status_code == 200
    options = first.json()["activity_options"]
    assert {item["label"].lower() for item in options} == {
        "swimming", "photography", "beach walking"
    }
    assert {item["option_id"] for item in options} == {
        item["option_id"] for item in second.json()["activity_options"]
    }
    for option in options:
        assert option["option_id"].startswith(f"activity:{destination['destination_id']}:")
        assert option["destination_id"] == destination["destination_id"]
        assert option["charge_type"] == "unknown"
        assert option["price"] is None
        assert option["price_basis"] is None
    assert first.json()["state"]["interests"] == ["coffee"]
    assert client.patch(
        f"/api/v1/destinations/{destination['destination_id']}",
        headers=admin,
        json={"activities": "beach walking, photography, swimming"},
    ).status_code == 200
    reordered = client.post("/api/v1/planning/preview", headers=user, json=request)
    assert reordered.status_code == 200
    assert {item["option_id"] for item in reordered.json()["activity_options"]} == {
        item["option_id"] for item in options
    }


def test_planning_preview_preserves_activity_paragraph_without_inventing_products(client) -> None:
    admin = register(client, admin=True)
    description = "Visitors can enjoy swimming, photography and picnics when conditions permit."
    destination = create_destination(client, admin, activities=description)

    response = client.post(
        "/api/v1/planning/preview",
        headers=register(client),
        json=preview_request(destination["destination_id"]),
    )

    assert response.status_code == 200
    assert response.json()["activity_options"] == []
    assert response.json()["destinations"][0]["activities_description"] == description


def test_planning_preview_preserves_restrictions_and_bracketed_activity_labels(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    user = register(client)
    examples = [
        ("No swimming, kayaking", []),
        ("Enjoy swimming, then relax by the shore.", []),
        ("Swimming (beginners, adults), photography", ["Swimming (beginners, adults)", "photography"]),
        ("Swimming (beginners, photography", []),
        ("1. Swimming\n2. Photography", ["Swimming", "Photography"]),
    ]
    for description, expected in examples:
        assert client.patch(
            f"/api/v1/destinations/{destination['destination_id']}",
            headers=admin,
            json={"activities": description},
        ).status_code == 200
        response = client.post(
            "/api/v1/planning/preview", headers=user,
            json=preview_request(destination["destination_id"]),
        )
        assert response.status_code == 200
        assert [item["label"] for item in response.json()["activity_options"]] == expected
        assert response.json()["destinations"][0]["activities_description"] == description


def test_planning_preview_has_no_choose_transport_action_for_missing_destinations(client) -> None:
    response = client.post(
        "/api/v1/planning/preview", headers=register(client), json=preview_request(999),
    )
    assert response.status_code == 200
    assert response.json()["transport_options"] == []
    assert "choose_transport" not in {item["code"] for item in response.json()["next_actions"]}
    assert response.json()["selection_problems"][0]["code"] == "destination_unavailable"


def test_planning_preview_discloses_removed_activity_without_replacing_selection(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin, activities="Swimming")
    user = register(client)
    request = preview_request(destination["destination_id"])
    first = client.post("/api/v1/planning/preview", headers=user, json=request)
    assert first.status_code == 200
    selected = first.json()["activity_options"][0]["option_id"]
    request["state"]["selected_activity_option_ids"] = [selected]
    assert client.patch(
        f"/api/v1/destinations/{destination['destination_id']}", headers=admin,
        json={"activities": "Photography"},
    ).status_code == 200
    changed = client.post("/api/v1/planning/preview", headers=user, json=request)
    assert changed.status_code == 200
    body = changed.json()
    assert body["state"]["selected_activity_option_ids"] == [selected]
    assert body["state"]["total_budget"] == request["state"]["total_budget"]
    assert body["selection_problems"][0]["code"] == "activity_option_unavailable"
    assert body["activity_options"][0]["label"] == "Photography"
    assert body["activity_options"][0]["selected"] is False


def test_planning_preview_retains_invalid_selections_and_filters_catalog_choices(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    unrelated = create_destination(client, admin, name="Other Test Beach", location="Mati City")
    inactive = create_destination(client, admin, name="Inactive Test Beach")
    valid_rate = create_transportation(client, admin, destination["destination_id"])
    unavailable_rate = create_transportation(client, admin, destination["destination_id"])
    unrelated_rate = create_transportation(client, admin, unrelated["destination_id"])
    inactive_rate = create_transportation(client, admin, inactive["destination_id"])
    assert client.delete(
        f"/api/v1/transportations/{unavailable_rate['transportation_id']}", headers=admin
    ).status_code == 200
    assert client.delete(
        f"/api/v1/destinations/{inactive['destination_id']}", headers=admin
    ).status_code == 200
    user = register(client)
    selected_transports = [
        f"transportation:{item['transportation_id']}"
        for item in (valid_rate, unavailable_rate, unrelated_rate, inactive_rate)
    ]
    request = preview_request(
        destination["destination_id"],
        destination_ids=[destination["destination_id"], inactive["destination_id"], 999],
        selected_transport_option_ids=selected_transports,
        selected_activity_option_ids=["activity:999:forged"],
    )

    response = client.post("/api/v1/planning/preview", headers=user, json=request)

    assert response.status_code == 200
    body = response.json()
    assert {key: body["state"][key] for key in request["state"]} == request["state"]
    assert body["status"] == "needs_selection_review"
    assert {item["destination_id"] for item in body["destinations"]} == {
        destination["destination_id"]
    }
    assert {
        item["option_id"]
        for item in body["transport_options"]
        if item["option_id"].startswith("transportation:")
    } == {f"transportation:{valid_rate['transportation_id']}"}
    problem_codes = [item["code"] for item in body["selection_problems"]]
    assert problem_codes.count("destination_unavailable") == 2
    assert problem_codes.count("transport_option_unavailable") == 3
    assert problem_codes.count("activity_option_unavailable") == 1


@pytest.mark.parametrize(
    "state_change",
    [
        {"price": "0.01"},
        {"selected_activity_prices": {"activity:1:forged": "0.01"}},
        {"day_count": 1, "night_count": 2},
        {"destination_ids": [1, 1]},
        {"origin": {"label": "Davao City", "lat": 7.07}},
    ],
)
def test_planning_preview_rejects_forged_prices_and_invalid_state(client, state_change) -> None:
    response = client.post(
        "/api/v1/planning/preview",
        headers=register(client),
        json=preview_request(1, **state_change),
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_planning_preview_needs_no_ai_or_route_provider_and_makes_no_writes(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    create_transportation(client, admin, destination["destination_id"])
    user = register(client)

    def unexpected_provider():
        raise AssertionError("Catalog preview must not request an external provider.")

    for provider in (get_groq_client, get_osrm_client, get_google_routes_client):
        client.app.dependency_overrides[provider] = unexpected_provider
    statements = []

    def record_statement(connection, cursor, statement, parameters, context, executemany):
        statements.append(statement.strip().split(maxsplit=1)[0].upper())

    event.listen(Engine, "before_cursor_execute", record_statement)
    try:
        response = client.post(
            "/api/v1/planning/preview",
            headers=user,
            json=preview_request(destination["destination_id"]),
        )
    finally:
        event.remove(Engine, "before_cursor_execute", record_statement)

    assert response.status_code == 200
    assert "SELECT" in statements
    assert not {"INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP"}.intersection(statements)
