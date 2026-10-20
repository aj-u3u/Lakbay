from decimal import Decimal

import pytest
from sqlalchemy import event
from sqlalchemy.engine import Engine

from app.integrations.google_routes.client import get_google_routes_client
from app.integrations.groq.client import get_groq_client
from app.integrations.osrm.client import get_osrm_client
from tests.test_planning_preview import (
    create_destination,
    create_transportation,
    preview_request,
    register,
)


def create_accommodation(client, headers, destination_id: int, **overrides) -> dict:
    response = client.post(
        f"/api/v1/destinations/{destination_id}/accommodations",
        headers=headers,
        json={
            "name": "Planning Test Stay",
            "room_type": "Standard Room",
            "price": "1000.00",
            "capacity": 2,
            **overrides,
        },
    )
    assert response.status_code == 201
    return response.json()


def request_preview(client, headers, request) -> dict:
    response = client.post("/api/v1/planning/preview", headers=headers, json=request)
    assert response.status_code == 200, response.text
    return response.json()


def baseline_allowances(destination_id: int, *, transport: bool = True) -> list[dict]:
    allowances = [
        {"category": "destination", "destination_id": destination_id, "amount": "100.00"},
        {"category": "food", "amount": "200.00"},
    ]
    if transport:
        allowances.append({"category": "transportation", "amount": "300.00"})
    return allowances


def budgeted_request(destination_id: int, **overrides) -> dict:
    return preview_request(
        destination_id,
        **{
            "selected_transport_option_ids": ["mode:personal_vehicle"],
            "cost_allowances": baseline_allowances(destination_id),
            **overrides,
        },
    )


@pytest.mark.parametrize(
    "first_scope,second_scope,second_direction",
    [
        ("round_trip", "listed_leg", "return"),
        ("round_trip", "round_trip", "outbound"),
        ("listed_leg", "listed_leg", "outbound"),
    ],
)
def test_planning_budget_does_not_double_charge_overlapping_journey_fares(
    client, first_scope, second_scope, second_direction,
) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    outbound = create_transportation(
        client, admin, destination["destination_id"],
        route_to=destination["name"], price="50000.00",
    )
    second = create_transportation(
        client, admin, destination["destination_id"],
        route_from=destination["name"] if second_direction == "return" else "Davao City",
        route_to="Davao City" if second_direction == "return" else destination["name"],
        price="50000.00",
    )
    ids = [f"transportation:{item['transportation_id']}" for item in (outbound, second)]
    body = request_preview(
        client, register(client),
        budgeted_request(
            destination["destination_id"], total_budget="1000.00", reserve_amount="0.00",
            selected_transport_option_ids=ids,
            cost_allowances=baseline_allowances(destination["destination_id"], transport=False),
            transport_pricing=[
                {"option_id": ids[0], "price_basis": "per_person", "journey_scope": first_scope},
                {"option_id": ids[1], "price_basis": "per_person", "journey_scope": second_scope},
            ],
        ),
    )
    assert body["budget"]["completeness"] == "partial"
    assert body["budget"]["fit"] == "undetermined"
    assert body["budget"]["category_totals"]["transportation"] == "0.00"
    assert body["budget"]["priced_subtotal"] == "300.00"
    assert body["budget"]["minimum_over_budget_amount"] == "0.00"
    assert sum(
        item["code"] == "pricing_assumption_invalid" for item in body["selection_problems"]
    ) == 2


def test_planning_budget_does_not_treat_catalog_zero_or_personal_vehicle_as_free(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin, estimated_cost="0.00", entrance_fee="0")
    user = register(client)
    first = request_preview(client, user, preview_request(destination["destination_id"]))
    activity_id = first["activity_options"][0]["option_id"]

    body = request_preview(
        client,
        user,
        preview_request(
            destination["destination_id"],
            selected_transport_option_ids=["mode:personal_vehicle"],
            selected_activity_option_ids=[activity_id],
        ),
    )

    budget = body["budget"]
    assert budget["completeness"] == "partial"
    assert budget["fit"] == "undetermined"
    assert budget["total_estimate"] is None
    assert budget["suggested_trip_funds"] is None
    assert budget["remaining_budget"] is None
    assert budget["missing_costs"]
    assert body["activity_options"][0]["charge_type"] == "unknown"
    assert not any(
        line["category"] in {"transportation", "destination", "activity"}
        for line in budget["lines"]
    )


def test_planning_budget_explicit_zero_allowances_remain_labeled_assumptions(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    user = register(client)
    allowances = baseline_allowances(destination["destination_id"])
    for allowance in allowances:
        allowance["amount"] = "0.00"

    body = request_preview(
        client,
        user,
        budgeted_request(destination["destination_id"], cost_allowances=allowances, reserve_amount="0.00"),
    )

    budget = body["budget"]
    assert budget["completeness"] == "complete"
    assert budget["fit"] == "fits_estimate"
    assert budget["priced_subtotal"] == "0.00"
    assert budget["total_estimate"] == "0.00"
    assert budget["remaining_budget"] == "15000.00"
    assert {line["source"] for line in budget["lines"]} == {"traveler_allowance"}
    assert {line["category"] for line in budget["lines"]} == {"destination", "food", "transportation"}
    assert budget["assumptions"]
    assert body["activity_options"][0]["charge_type"] == "unknown"
    assert not any(line["category"] == "accommodation" for line in budget["lines"])


def test_planning_budget_prices_server_fare_per_person_and_reloads_changed_rate(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    transportation = create_transportation(
        client, admin, destination["destination_id"], route_to=destination["name"]
    )
    user = register(client)
    option_id = f"transportation:{transportation['transportation_id']}"
    request = budgeted_request(
        destination["destination_id"],
        traveler_count=3,
        return_to_origin=False,
        selected_transport_option_ids=[option_id],
        cost_allowances=baseline_allowances(destination["destination_id"], transport=False),
        transport_pricing=[{"option_id": option_id, "price_basis": "per_person"}],
    )

    without_basis = request_preview(
        client,
        user,
        {**request, "state": {**request["state"], "transport_pricing": []}},
    )
    assert without_basis["budget"]["completeness"] == "partial"
    assert without_basis["budget"]["priced_subtotal"] == "300.00"
    assert not any(line["category"] == "transportation" for line in without_basis["budget"]["lines"])
    body = request_preview(client, user, request)

    budget = body["budget"]
    assert budget["completeness"] == "complete"
    assert budget["priced_subtotal"] == "660.00"
    fare = next(line for line in budget["lines"] if line["category"] == "transportation")
    assert fare["unit_amount"] == "120.00"
    assert fare["quantity"] == 3
    assert fare["amount"] == "360.00"
    assert fare["price_basis"] == "per_person"
    assert fare["source"] == "catalog_price_with_assumed_basis"
    assert client.patch(
        f"/api/v1/transportations/{transportation['transportation_id']}",
        headers=admin,
        json={"price": "200.00"},
    ).status_code == 200

    changed = request_preview(client, user, request)

    assert changed["budget"]["priced_subtotal"] == "900.00"
    assert changed["state"]["transport_pricing"][0]["option_id"] == option_id
    assert any(
        line["unit_amount"] == "200.00" and line["amount"] == "600.00"
        for line in changed["budget"]["lines"]
    )


@pytest.mark.parametrize(
    "price_basis,vehicle_count,quantity,amount",
    [("per_vehicle", 2, 4, "480.00"), ("per_group", 1, 2, "240.00")],
)
def test_planning_budget_uses_vehicle_or_group_charge_units_without_passenger_multiplier(
    client, price_basis, vehicle_count, quantity, amount
) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    transportation = create_transportation(
        client, admin, destination["destination_id"], route_to=destination["name"]
    )
    option_id = f"transportation:{transportation['transportation_id']}"

    body = request_preview(
        client,
        register(client),
        budgeted_request(
            destination["destination_id"],
            traveler_count=5,
            return_to_origin=False,
            selected_transport_option_ids=[option_id],
            cost_allowances=baseline_allowances(destination["destination_id"], transport=False),
            transport_pricing=[
                {
                    "option_id": option_id,
                    "price_basis": price_basis,
                    "charge_count": 2,
                    "vehicle_count": vehicle_count,
                }
            ],
        ),
    )

    assert body["budget"]["completeness"] == "complete"
    fare = next(line for line in body["budget"]["lines"] if line["category"] == "transportation")
    assert fare["quantity"] == quantity
    assert fare["amount"] == amount
    assert fare["price_basis"] == price_basis


@pytest.mark.parametrize(
    ("journey_scope", "completeness", "fit"),
    [("listed_leg", "partial", "undetermined"), ("round_trip", "complete", "fits_estimate")],
)
def test_planning_budget_requires_return_coverage_without_automatically_doubling_fare(
    client, journey_scope, completeness, fit
) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    transportation = create_transportation(
        client, admin, destination["destination_id"], route_to=destination["name"]
    )
    option_id = f"transportation:{transportation['transportation_id']}"

    body = request_preview(
        client,
        register(client),
        budgeted_request(
            destination["destination_id"],
            traveler_count=3,
            return_to_origin=True,
            selected_transport_option_ids=[option_id],
            cost_allowances=baseline_allowances(destination["destination_id"], transport=False),
            transport_pricing=[
                {"option_id": option_id, "price_basis": "per_person", "journey_scope": journey_scope}
            ],
        ),
    )

    budget = body["budget"]
    assert budget["completeness"] == completeness
    assert budget["fit"] == fit
    assert budget["priced_subtotal"] == "660.00"
    assert body["transport_options"][1]["journey_complete"] is False
    if completeness == "partial":
        assert budget["total_estimate"] is None
        assert budget["remaining_budget"] is None
    else:
        assert budget["total_estimate"] == "660.00"
        assert budget["assumptions"]


@pytest.mark.parametrize(
    "price_basis,quantity,accommodation_total,subtotal",
    [
        ("per_room_per_night", 4, "4000.00", "4600.00"),
        ("per_room_per_stay", 2, "2000.00", "2600.00"),
    ],
)
def test_planning_budget_uses_explicit_room_basis_and_capacity(
    client, price_basis, quantity, accommodation_total, subtotal
) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    accommodation = create_accommodation(client, admin, destination["destination_id"])
    request = budgeted_request(
        destination["destination_id"],
        traveler_count=3,
        day_count=3,
        night_count=2,
        selected_accommodation_ids=[accommodation["accommodation_id"]],
        accommodation_pricing=[
            {
                "accommodation_id": accommodation["accommodation_id"],
                "price_basis": price_basis,
                "room_count": 2,
                "night_count": 2,
            }
        ],
    )

    body = request_preview(client, register(client), request)

    budget = body["budget"]
    assert budget["completeness"] == "complete"
    assert budget["category_totals"]["accommodation"] == accommodation_total
    assert budget["priced_subtotal"] == subtotal
    room_line = next(line for line in budget["lines"] if line["category"] == "accommodation")
    assert room_line["quantity"] == quantity
    assert room_line["unit_amount"] == "1000.00"
    assert room_line["amount"] == accommodation_total


def test_planning_budget_return_only_fare_cannot_complete_outbound_journey(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    inbound = create_transportation(
        client,
        admin,
        destination["destination_id"],
        route_from=destination["name"],
        route_to="Davao City",
    )
    option_id = f"transportation:{inbound['transportation_id']}"

    body = request_preview(
        client,
        register(client),
        budgeted_request(
            destination["destination_id"],
            return_to_origin=False,
            selected_transport_option_ids=[option_id],
            cost_allowances=baseline_allowances(destination["destination_id"], transport=False),
            transport_pricing=[{"option_id": option_id, "price_basis": "per_person"}],
        ),
    )

    assert body["budget"]["completeness"] == "partial"
    assert body["budget"]["fit"] == "undetermined"
    assert body["budget"]["remaining_budget"] is None
    assert body["budget"]["category_totals"]["transportation"] == "0.00"
    assert any(item["code"] == "pricing_assumption_invalid" for item in body["selection_problems"])


def test_planning_budget_fare_to_one_stop_does_not_cover_multiple_destinations(client) -> None:
    admin = register(client, admin=True)
    first = create_destination(client, admin)
    second = create_destination(client, admin, name="Second Test Beach")
    transportation = create_transportation(
        client, admin, first["destination_id"], route_to=first["name"]
    )
    option_id = f"transportation:{transportation['transportation_id']}"
    allowances = baseline_allowances(first["destination_id"], transport=False)
    allowances.append(
        {"category": "destination", "destination_id": second["destination_id"], "amount": "100.00"}
    )
    request = budgeted_request(
        first["destination_id"],
        destination_ids=[first["destination_id"], second["destination_id"]],
        return_to_origin=False,
        selected_transport_option_ids=[option_id],
        cost_allowances=allowances,
        transport_pricing=[{"option_id": option_id, "price_basis": "per_person"}],
    )
    user = register(client)

    partial = request_preview(client, user, request)

    assert partial["budget"]["completeness"] == "partial"
    assert partial["budget"]["fit"] == "undetermined"
    assert partial["budget"]["category_totals"]["transportation"] == "120.00"
    assert partial["budget"]["remaining_budget"] is None
    allowances.append({"category": "transportation", "amount": "300.00"})

    complete = request_preview(client, user, request)

    assert complete["budget"]["completeness"] == "complete"
    assert complete["budget"]["fit"] == "fits_estimate"
    assert complete["budget"]["category_totals"]["transportation"] == "300.00"
    assert complete["budget"]["priced_subtotal"] == "700.00"


@pytest.mark.parametrize("room_count,allocated_nights", [(1, 2), (2, 1), (2, 3)])
def test_planning_budget_discloses_insufficient_rooms_or_wrong_night_allocation(
    client, room_count, allocated_nights
) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    accommodation = create_accommodation(client, admin, destination["destination_id"])

    body = request_preview(
        client,
        register(client),
        budgeted_request(
            destination["destination_id"],
            traveler_count=3,
            day_count=3,
            night_count=2,
            selected_accommodation_ids=[accommodation["accommodation_id"]],
            accommodation_pricing=[
                {
                    "accommodation_id": accommodation["accommodation_id"],
                    "price_basis": "per_room_per_night",
                    "room_count": room_count,
                    "night_count": allocated_nights,
                }
            ],
        ),
    )

    assert body["budget"]["completeness"] == "partial"
    assert body["budget"]["fit"] == "undetermined"
    assert body["budget"]["remaining_budget"] is None
    assert body["budget"]["missing_costs"] or body["selection_problems"]


def test_planning_budget_whole_transport_allowance_replaces_fares_and_car_fuel_cost(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    transportation = create_transportation(client, admin, destination["destination_id"])
    option_id = f"transportation:{transportation['transportation_id']}"

    body = request_preview(
        client,
        register(client),
        budgeted_request(
            destination["destination_id"],
            selected_transport_option_ids=[option_id],
            transport_pricing=[{"option_id": option_id, "price_basis": "per_person"}],
        ),
    )

    budget = body["budget"]
    assert budget["completeness"] == "complete"
    assert budget["category_totals"]["transportation"] == "300.00"
    transport_lines = [line for line in budget["lines"] if line["category"] == "transportation"]
    assert len(transport_lines) == 1
    assert transport_lines[0]["source"] == "traveler_allowance"
    assert budget["priced_subtotal"] == "600.00"


def test_planning_budget_reserve_is_separate_from_expenses_and_can_exceed_budget(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)

    body = request_preview(
        client,
        register(client),
        budgeted_request(destination["destination_id"], total_budget="1000.00", reserve_amount="500.00"),
    )

    budget = body["budget"]
    assert budget["completeness"] == "complete"
    assert budget["fit"] == "over_budget"
    assert budget["priced_subtotal"] == "600.00"
    assert budget["total_estimate"] == "600.00"
    assert budget["reserve_amount"] == "500.00"
    assert budget["suggested_trip_funds"] == "1100.00"
    assert budget["remaining_budget"] == "0.00"
    assert budget["over_budget_amount"] == "100.00"
    assert sum(Decimal(line["amount"]) for line in budget["lines"]) == Decimal("600.00")
    assert any(action["code"] == "reduce_costs" for action in body["next_actions"])


def test_planning_budget_partial_costs_can_prove_minimum_overage(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)

    body = request_preview(
        client,
        register(client),
        budgeted_request(
            destination["destination_id"],
            total_budget="1000.00",
            reserve_amount="100.00",
            cost_allowances=[{"category": "food", "amount": "1500.00"}],
        ),
    )

    budget = body["budget"]
    assert budget["completeness"] == "partial"
    assert budget["fit"] == "over_budget"
    assert budget["priced_subtotal"] == "1500.00"
    assert budget["minimum_over_budget_amount"] == "600.00"
    assert budget["total_estimate"] is None
    assert budget["remaining_budget"] is None


def test_planning_budget_included_activity_is_not_charged_twice(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    user = register(client)
    first = request_preview(client, user, preview_request(destination["destination_id"]))
    activity_id = first["activity_options"][0]["option_id"]
    allowances = baseline_allowances(destination["destination_id"])
    allowances[0]["includes_activity_option_ids"] = [activity_id]

    body = request_preview(
        client,
        user,
        budgeted_request(
            destination["destination_id"],
            selected_activity_option_ids=[activity_id],
            cost_allowances=allowances,
        ),
    )

    budget = body["budget"]
    assert budget["completeness"] == "complete"
    assert budget["priced_subtotal"] == "600.00"
    activity_line = next(line for line in budget["lines"] if line["category"] == "activity")
    assert activity_line["source"] == "included_in_allowance"
    assert activity_line["amount"] == "0.00"
    assert activity_line["included_in"] is not None

    allowances.append({"category": "activity", "option_id": activity_id, "amount": "50.00"})
    conflict = request_preview(
        client,
        user,
        budgeted_request(
            destination["destination_id"],
            selected_activity_option_ids=[activity_id],
            cost_allowances=allowances,
        ),
    )

    assert conflict["budget"]["completeness"] == "partial"
    assert conflict["budget"]["priced_subtotal"] == "600.00"
    assert any(item["code"] == "cost_allowance_invalid" for item in conflict["selection_problems"])


def test_planning_budget_food_allowance_can_include_catalog_dining_without_duplicate_cost(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin, activities="Coffee, dining")
    user = register(client)
    first = request_preview(client, user, preview_request(destination["destination_id"]))
    activity_id = next(
        option["option_id"] for option in first["activity_options"] if option["label"].lower() == "coffee"
    )
    allowances = baseline_allowances(destination["destination_id"])
    food_allowance = next(item for item in allowances if item["category"] == "food")
    food_allowance["includes_activity_option_ids"] = [activity_id]
    request = budgeted_request(
        destination["destination_id"],
        selected_activity_option_ids=[activity_id],
        cost_allowances=allowances,
    )

    body = request_preview(client, user, request)

    assert body["budget"]["completeness"] == "complete"
    assert body["budget"]["priced_subtotal"] == "600.00"
    activity_line = next(line for line in body["budget"]["lines"] if line["category"] == "activity")
    assert activity_line["source"] == "included_in_allowance"
    assert activity_line["amount"] == "0.00"
    assert activity_line["included_in"] is not None
    allowances.append({"category": "activity", "option_id": activity_id, "amount": "50.00"})

    conflicting = request_preview(client, user, request)

    assert conflicting["budget"]["completeness"] == "partial"
    assert conflicting["budget"]["priced_subtotal"] == "600.00"
    assert any(item["code"] == "cost_allowance_invalid" for item in conflicting["selection_problems"])


def test_planning_budget_overlap_cannot_use_invalid_food_amount_to_prove_overage(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin, activities="Coffee, dining")
    user = register(client)
    first = request_preview(client, user, preview_request(destination["destination_id"]))
    activity_id = next(
        option["option_id"] for option in first["activity_options"] if option["label"].lower() == "coffee"
    )
    allowances = baseline_allowances(destination["destination_id"])
    allowances[0]["includes_activity_option_ids"] = [activity_id]
    food = next(item for item in allowances if item["category"] == "food")
    food["amount"] = "90000.00"
    food["includes_activity_option_ids"] = [activity_id]

    body = request_preview(
        client,
        user,
        budgeted_request(
            destination["destination_id"],
            total_budget="1000.00",
            reserve_amount="0.00",
            selected_activity_option_ids=[activity_id],
            cost_allowances=allowances,
        ),
    )

    assert body["budget"]["completeness"] == "partial"
    assert body["budget"]["fit"] == "undetermined"
    assert body["budget"]["category_totals"]["food"] == "0.00"
    assert body["budget"]["priced_subtotal"] == "400.00"
    assert body["budget"]["minimum_over_budget_amount"] == "0.00"
    assert any(item["code"] == "cost_allowance_invalid" for item in body["selection_problems"])
    assert next(item for item in body["state"]["cost_allowances"] if item["category"] == "food")["amount"] == "90000.00"


def test_planning_budget_rejects_stale_allowance_target_without_clearing_state(client) -> None:
    admin = register(client, admin=True)
    previous = create_destination(client, admin)
    current = create_destination(client, admin, name="New Test Beach")
    allowances = baseline_allowances(previous["destination_id"])
    request = budgeted_request(current["destination_id"], cost_allowances=allowances)

    body = request_preview(client, register(client), request)

    assert body["budget"]["completeness"] == "partial"
    assert body["budget"]["fit"] == "undetermined"
    assert any(item["code"] == "cost_allowance_invalid" for item in body["selection_problems"])
    assert body["state"]["cost_allowances"][0]["destination_id"] == previous["destination_id"]
    assert body["budget"]["category_totals"].get("destination", "0.00") == "0.00"


def test_planning_budget_ignores_deactivated_selected_stays(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    accommodation = create_accommodation(client, admin, destination["destination_id"])
    assert client.delete(
        f"/api/v1/accommodations/{accommodation['accommodation_id']}", headers=admin
    ).status_code == 200

    body = request_preview(
        client,
        register(client),
        budgeted_request(
            destination["destination_id"],
            day_count=2,
            night_count=1,
            selected_accommodation_ids=[accommodation["accommodation_id"]],
            accommodation_pricing=[
                {
                    "accommodation_id": accommodation["accommodation_id"],
                    "price_basis": "per_room_per_night",
                    "room_count": 1,
                    "night_count": 1,
                }
            ],
        ),
    )

    assert body["accommodation_options"] == []
    assert body["state"]["selected_accommodation_ids"] == [accommodation["accommodation_id"]]
    assert any(item["code"] == "accommodation_option_unavailable" for item in body["selection_problems"])
    assert body["budget"]["completeness"] == "partial"
    assert not any(line["category"] == "accommodation" for line in body["budget"]["lines"])


@pytest.mark.parametrize(
    "pricing",
    [
        {"option_id": "transportation:1", "price_basis": "per_person", "price": "0.01"},
        {"option_id": "transportation:1", "price_basis": "per_person", "vehicle_count": 2},
    ],
)
def test_planning_budget_rejects_forged_catalog_price_or_invalid_multiplier(client, pricing) -> None:
    response = client.post(
        "/api/v1/planning/preview",
        headers=register(client),
        json=budgeted_request(1, transport_pricing=[pricing]),
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_planning_budget_recalculates_without_writes_or_external_providers(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    user = register(client)

    def unexpected_provider():
        raise AssertionError("Cost recalculation must not request an external provider.")

    for provider in (get_groq_client, get_osrm_client, get_google_routes_client):
        client.app.dependency_overrides[provider] = unexpected_provider
    statements = []

    def record_statement(connection, cursor, statement, parameters, context, executemany):
        statements.append(statement.strip().split(maxsplit=1)[0].upper())

    event.listen(Engine, "before_cursor_execute", record_statement)
    try:
        first = request_preview(client, user, budgeted_request(destination["destination_id"]))
        second = request_preview(
            client,
            user,
            {"input_revision": 8, "state": {**first["state"], "reserve_amount": "0.00"}},
        )
    finally:
        event.remove(Engine, "before_cursor_execute", record_statement)

    assert second["input_revision"] == 8
    assert first["budget"]["suggested_trip_funds"] == "1100.00"
    assert second["budget"]["suggested_trip_funds"] == "600.00"
    assert "SELECT" in statements
    assert not {"INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP"}.intersection(statements)
