from decimal import Decimal
from typing import Annotated

import pytest
from fastapi import Depends
from sqlalchemy import event
from sqlalchemy.engine import Engine
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import provider_usage
from app.core.config import get_settings
from app.core.exceptions import LakbayAPIError
from app.db.session import get_db_session
from app.features.planning import dependencies as planning_dependencies
from app.features.planning.dependencies import (
    PlanningRouteLimiter,
    get_planning_route_limiter,
    get_planning_route_service,
)
from app.features.routes.service import RouteService
from app.integrations.google_routes.client import get_google_routes_client
from app.integrations.groq.client import get_groq_client
from app.integrations.osrm.client import get_osrm_client
from app.integrations.osrm.errors import OSRMClientError
from app.integrations.osrm.schemas import OSRMLeg, OSRMRouteResult
from tests.test_phase6_routes import FakeOSRMClient
from tests.test_planning_preview import (
    create_destination,
    create_transportation,
    preview_request,
    register,
)


def override_route_service(client, fake_osrm) -> None:
    async def service(
        session: Annotated[AsyncSession, Depends(get_db_session)],
    ) -> RouteService:
        return RouteService(session, fake_osrm)

    client.app.dependency_overrides[get_planning_route_service] = service


def route_result(*distances: int, stop_order=None) -> OSRMRouteResult:
    return OSRMRouteResult(
        total_distance_meters=sum(distances),
        total_duration_seconds=len(distances) * 600,
        legs=[OSRMLeg(distance_meters=value, duration_seconds=600) for value in distances],
        stop_order=stop_order,
    )


def fuel_assumptions(**overrides) -> dict:
    return {
        "kilometers_per_liter": "10.00",
        "price_per_liter": "60.00",
        "vehicle_count": 1,
        "parking_amount": "0.00",
        "toll_amount": "0.00",
        "vehicle_ferry_amount": "0.00",
        "other_vehicle_amount": "0.00",
        **overrides,
    }


def routing_request(destination_id: int, **overrides) -> dict:
    state = {
        "reserve_amount": "0.00",
        "selected_transport_option_ids": ["mode:personal_vehicle"],
        "route_preferences": {"road_access_confirmed": True},
        "fuel_assumptions": fuel_assumptions(),
        "cost_allowances": [
            {"category": "destination", "destination_id": destination_id, "amount": "100.00"},
            {"category": "food", "amount": "200.00"},
        ],
        **overrides,
    }
    return preview_request(destination_id, **state)


def post_preview(client, headers, request) -> dict:
    response = client.post("/api/v1/planning/preview", headers=headers, json=request)
    assert response.status_code == 200, response.text
    return response.json()


def test_preview_routes_are_opt_in_and_old_requests_need_no_provider(client, monkeypatch) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    user = register(client)

    def unexpected_provider():
        raise AssertionError("An old planning request must not construct a route provider.")

    for provider in (get_osrm_client, get_google_routes_client, get_groq_client):
        client.app.dependency_overrides[provider] = unexpected_provider
    monkeypatch.setattr(planning_dependencies, "get_osrm_client", unexpected_provider)

    body = post_preview(client, user, preview_request(destination["destination_id"]))

    assert body["route"]["status"] == "not_requested"
    assert body["route"]["summary"] is None
    assert body["fuel"]["status"] == "not_requested"
    assert body["budget"]["completeness"] == "partial"


def test_fuel_inputs_without_route_opt_in_are_retained_but_not_priced(client, monkeypatch) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    user = register(client)

    def unexpected_provider():
        raise AssertionError("Fuel assumptions alone do not authorize routing provider work.")

    monkeypatch.setattr(planning_dependencies, "get_osrm_client", unexpected_provider)
    request = routing_request(destination["destination_id"], route_preferences=None)

    body = post_preview(client, user, request)

    assert body["route"]["status"] == "not_requested"
    assert body["route"]["summary"] is None
    assert body["state"]["fuel_assumptions"] == request["state"]["fuel_assumptions"]
    assert body["fuel"]["status"] == "unavailable"
    assert body["fuel"]["amount"] is None
    assert body["budget"]["completeness"] == "partial"


def test_road_access_confirmation_is_required_for_fuel_but_not_existing_allowance(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(preview_result=route_result(10000, 20000))
    override_route_service(client, fake)
    request = routing_request(destination["destination_id"], route_preferences={})
    request["state"]["cost_allowances"].append({"category": "transportation", "amount": "500.00"})

    body = post_preview(client, register(client), request)

    assert body["route"]["status"] == "needs_review"
    assert body["route"]["summary"]["route_provider"] == "osrm"
    assert body["fuel"]["status"] == "needs_details"
    assert body["fuel"]["amount"] is None
    assert body["budget"]["completeness"] == "complete"
    assert body["budget"]["total_estimate"] == "800.00"


def test_personal_route_prices_asymmetric_outbound_and_return_once_per_vehicle(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(preview_result=route_result(10000, 20000))
    override_route_service(client, fake)

    body = post_preview(
        client,
        register(client),
        routing_request(
            destination["destination_id"],
            traveler_count=4,
            fuel_assumptions=fuel_assumptions(vehicle_count=2),
        ),
    )

    route = body["route"]
    assert route["status"] == "calculated"
    assert route["travel_mode"] == "driving"
    assert route["order_strategy"] == "preserve_order"
    assert route["summary"]["total_distance_km"] == "30.00"
    assert [Decimal(leg["distance_km"]) for leg in route["summary"]["legs"]] == [
        Decimal("10"), Decimal("20")
    ]
    assert [stop["destination_id"] for stop in route["summary"]["stops"]] == [
        None, destination["destination_id"], None
    ]
    assert len(fake.preview_calls) == 1
    assert len(fake.preview_calls[0]["coordinates"]) == 3
    assert fake.optimize_calls == []
    fuel = body["fuel"]
    assert fuel["status"] == "calculated"
    assert Decimal(fuel["distance_km"]) == Decimal("30")
    assert Decimal(fuel["liters"]) == Decimal("6")
    assert Decimal(fuel["amount"]) == Decimal("360")
    assert fuel["vehicle_count"] == 2
    assert fuel["assumptions"]
    assert body["budget"]["completeness"] == "complete"
    assert body["budget"]["category_totals"]["transportation"] == "360.00"
    assert body["budget"]["total_estimate"] == "660.00"
    assert sum(Decimal(line["amount"]) for line in body["budget"]["lines"]) == Decimal("660")
    assert any(
        line["source"] == "route_with_traveler_assumptions"
        for line in body["budget"]["lines"] if line["category"] == "transportation"
    )


def test_one_way_personal_route_has_no_implicit_return_or_passenger_multiplier(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(preview_result=route_result(12500))
    override_route_service(client, fake)

    body = post_preview(
        client,
        register(client),
        routing_request(destination["destination_id"], traveler_count=5, return_to_origin=False),
    )

    assert len(fake.preview_calls[0]["coordinates"]) == 2
    assert Decimal(body["fuel"]["amount"]) == Decimal("75")
    assert Decimal(body["fuel"]["liters"]) == Decimal("1.25")
    assert body["budget"]["total_estimate"] == "375.00"


def test_fuel_price_uses_unrounded_liters_before_money_rounding(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(preview_result=route_result(10000, 20000))
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(
            destination["destination_id"],
            fuel_assumptions=fuel_assumptions(kilometers_per_liter="7.00", price_per_liter="63.79"),
        ),
    )

    assert Decimal(body["fuel"]["liters"]) == Decimal("4.286")
    assert Decimal(body["fuel"]["amount"]) == Decimal("273.39")
    assert body["budget"]["total_estimate"] == "573.39"


def test_missing_fuel_assumptions_does_not_block_route_but_keeps_budget_partial(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(preview_result=route_result(10000, 20000))
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(destination["destination_id"], fuel_assumptions=None),
    )

    assert body["route"]["status"] == "calculated"
    assert body["fuel"]["status"] == "needs_details"
    assert body["fuel"]["amount"] is None
    assert body["fuel"]["missing_information"]
    assert body["budget"]["completeness"] == "partial"


def test_whole_transport_allowance_includes_fuel_without_duplicate_charge(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(preview_result=route_result(10000, 20000))
    override_route_service(client, fake)
    request = routing_request(destination["destination_id"])
    request["state"]["cost_allowances"].append({"category": "transportation", "amount": "500.00"})

    body = post_preview(client, register(client), request)

    assert Decimal(body["fuel"]["amount"]) == Decimal("180")
    assert body["fuel"]["included_in"] == "allowance:transportation"
    assert body["budget"]["completeness"] == "complete"
    assert body["budget"]["category_totals"]["transportation"] == "500.00"
    assert body["budget"]["total_estimate"] == "800.00"
    assert sum(
        Decimal(line["amount"]) for line in body["budget"]["lines"]
        if line["category"] == "transportation"
    ) == Decimal("500")


def test_vehicle_expenses_are_trip_allowances_added_once(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(preview_result=route_result(10000, 20000))
    override_route_service(client, fake)

    body = post_preview(
        client,
        register(client),
        routing_request(
            destination["destination_id"], traveler_count=4,
            fuel_assumptions=fuel_assumptions(
                vehicle_count=2, parking_amount="25.00", toll_amount="10.00",
                vehicle_ferry_amount="0.00", other_vehicle_amount="5.00",
            ),
        ),
    )

    assert body["budget"]["completeness"] == "complete"
    assert body["budget"]["category_totals"]["transportation"] == "400.00"
    assert body["budget"]["total_estimate"] == "700.00"


@pytest.mark.parametrize("unknown_fee", ["parking_amount", "toll_amount", "vehicle_ferry_amount", "other_vehicle_amount"])
def test_unknown_vehicle_fee_keeps_full_budget_unresolved(client, unknown_fee) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(preview_result=route_result(10000, 20000))
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(
            destination["destination_id"],
            fuel_assumptions=fuel_assumptions(**{unknown_fee: None}),
        ),
    )

    assert body["fuel"]["status"] == "calculated"
    assert body["budget"]["priced_subtotal"] == "480.00"
    assert body["budget"]["completeness"] == "partial"
    assert body["budget"]["total_estimate"] is None
    assert body["budget"]["remaining_budget"] is None
    assert body["budget"]["missing_costs"]


def test_haversine_fallback_never_produces_road_fuel_or_complete_budget(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(error=OSRMClientError("Route provider unavailable"))
    override_route_service(client, fake)

    body = post_preview(client, register(client), routing_request(destination["destination_id"]))

    assert body["route"]["summary"]["route_provider"] == "haversine"
    assert body["route"]["summary"]["is_estimated"] is True
    assert body["fuel"]["status"] == "unavailable"
    assert body["fuel"]["amount"] is None
    assert body["budget"]["category_totals"]["transportation"] == "0.00"
    assert body["budget"]["completeness"] == "partial"


@pytest.mark.parametrize(
    "state_change",
    [
        {"origin": {"label": "Davao City"}},
        {"return_to_origin": None},
        {"selected_transport_option_ids": []},
    ],
)
def test_missing_route_details_do_not_call_provider_or_block_other_preview_sections(client, state_change) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(error=AssertionError("Incomplete details must not call OSRM"))
    override_route_service(client, fake)

    body = post_preview(client, register(client), routing_request(destination["destination_id"], **state_change))

    assert body["route"]["status"] == "needs_details"
    assert body["route"]["summary"] is None
    assert body["route"]["missing_information"]
    assert body["fuel"]["amount"] is None
    assert body["destinations"][0]["destination_id"] == destination["destination_id"]
    assert "budget" in body
    assert fake.preview_calls == fake.optimize_calls == []


def test_inactive_stop_does_not_create_route_for_remaining_subset(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    inactive = create_destination(client, admin, name="Removed Route Stop")
    assert client.delete(f"/api/v1/destinations/{inactive['destination_id']}", headers=admin).status_code == 200
    ids = [destination["destination_id"], inactive["destination_id"]]
    fake = FakeOSRMClient(error=AssertionError("Unavailable stops must not be silently omitted"))
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(destination["destination_id"], destination_ids=ids),
    )

    assert body["state"]["destination_ids"] == ids
    assert body["route"]["status"] == "needs_review"
    assert body["route"]["summary"] is None
    assert body["budget"]["completeness"] == "partial"
    assert any(item["code"] == "destination_unavailable" for item in body["selection_problems"])
    assert fake.preview_calls == fake.optimize_calls == []


@pytest.mark.parametrize(
    "destination_change",
    [
        {"transport_accessibility": "Ferry and private car"},
        {"how_to_get_there": "Ride a boat to the island."},
        {"travel_notes": "Vehicle ferry connection required."},
    ],
)
def test_known_nonroad_connection_overrides_traveler_road_confirmation(client, destination_change) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin, **destination_change)
    fake = FakeOSRMClient(error=AssertionError("Road confirmation cannot erase ferry connections"))
    override_route_service(client, fake)

    body = post_preview(client, register(client), routing_request(destination["destination_id"]))

    assert body["route"]["status"] == "needs_review"
    assert body["route"]["summary"] is None
    assert body["fuel"]["amount"] is None
    assert body["budget"]["completeness"] == "partial"
    assert fake.preview_calls == fake.optimize_calls == []


@pytest.mark.parametrize(
    "destination_change,expected_status",
    [
        ({"how_to_get_there": "Take an air-conditioned bus."}, "calculated"),
        ({"travel_notes": "Enjoy fresh air and a sea view from the seawall."}, "calculated"),
        ({"transport_accessibility": "air"}, "needs_review"),
        ({"transport_accessibility": "sea"}, "needs_review"),
        ({"how_to_get_there": "Travel by air to the destination."}, "needs_review"),
        ({"travel_notes": "Arrival via sea transport."}, "needs_review"),
    ],
)
def test_access_notes_distinguish_transport_connections_from_road_trip_prose(
    client, destination_change, expected_status,
) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin, **destination_change)
    fake = FakeOSRMClient(preview_result=route_result(10000, 20000))
    override_route_service(client, fake)

    body = post_preview(client, register(client), routing_request(destination["destination_id"]))

    assert body["route"]["status"] == expected_status
    if expected_status == "calculated":
        assert body["fuel"]["status"] == "calculated"
        assert len(fake.preview_calls) == 1
    else:
        assert body["fuel"]["amount"] is None
        assert fake.preview_calls == []


@pytest.mark.parametrize(
    "vehicle_type,transport_mode",
    [
        ("Ferry", "sea"), ("Airplane", "air"), ("Boat", "public_transport"),
        ("Bus and ferry", "mixed"), ("Experimental vehicle", "unknown"),
    ],
)
def test_nonroad_catalog_transport_never_becomes_driving_route(client, vehicle_type, transport_mode) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    transportation = create_transportation(
        client, admin, destination["destination_id"],
        vehicle_type=vehicle_type, transport_mode=transport_mode,
    )
    fake = FakeOSRMClient(error=AssertionError("Non-road catalog transport cannot use OSRM"))
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(
            destination["destination_id"],
            selected_transport_option_ids=[f"transportation:{transportation['transportation_id']}"],
        ),
    )

    assert body["route"]["status"] == "needs_review"
    assert body["route"]["summary"] is None
    assert body["fuel"]["amount"] is None
    assert fake.preview_calls == fake.optimize_calls == []


def test_public_transport_route_is_estimated_and_has_no_car_fuel(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    transportation = create_transportation(client, admin, destination["destination_id"])
    fake = FakeOSRMClient(error=AssertionError("Public transport estimates must not call OSRM"))
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(
            destination["destination_id"],
            selected_transport_option_ids=[f"transportation:{transportation['transportation_id']}"],
        ),
    )

    assert body["route"]["travel_mode"] == "public_transport"
    assert body["route"]["summary"]["route_provider"] == "stored_transportation_estimate"
    assert body["route"]["summary"]["is_estimated"] is True
    assert body["fuel"]["amount"] is None
    assert body["budget"]["completeness"] == "partial"
    assert fake.preview_calls == fake.optimize_calls == []


@pytest.mark.parametrize("transport_mode", ["private_vehicle", "Private Car"])
def test_catalog_private_car_uses_road_route_without_traveler_fuel(client, transport_mode) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    transportation = create_transportation(
        client, admin, destination["destination_id"],
        vehicle_type="Private Car", transport_mode=transport_mode,
    )
    fake = FakeOSRMClient(preview_result=route_result(10000, 20000))
    override_route_service(client, fake)

    # A hired car's driver handles road access, so no traveler confirmation is sent.
    body = post_preview(
        client, register(client),
        routing_request(
            destination["destination_id"], route_preferences={},
            selected_transport_option_ids=[f"transportation:{transportation['transportation_id']}"],
        ),
    )

    assert body["route"]["status"] == "calculated"
    assert body["route"]["travel_mode"] == "driving"
    assert body["route"]["summary"]["route_provider"] == "osrm"
    assert "road_access_confirmation" not in body["route"]["missing_information"]
    assert fake.preview_calls[0]["travel_mode"] == "driving"
    assert body["fuel"]["status"] == "unavailable"
    assert body["fuel"]["missing_information"] == ["sole_personal_vehicle_selection"]
    assert body["fuel"]["amount"] is None


def test_private_car_with_shared_transport_stays_an_estimated_commute(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    car = create_transportation(
        client, admin, destination["destination_id"],
        vehicle_type="Private Car", transport_mode="private_vehicle",
    )
    bus = create_transportation(client, admin, destination["destination_id"])
    fake = FakeOSRMClient(error=AssertionError("Mixed public and private choices are estimated"))
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(
            destination["destination_id"],
            selected_transport_option_ids=[
                f"transportation:{car['transportation_id']}",
                f"transportation:{bus['transportation_id']}",
            ],
        ),
    )

    assert body["route"]["travel_mode"] == "public_transport"
    assert body["route"]["summary"]["route_provider"] == "stored_transportation_estimate"
    assert fake.preview_calls == fake.optimize_calls == []


def test_walking_choice_uses_walking_route_and_no_vehicle_fuel(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(preview_result=route_result(1500))
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(
            destination["destination_id"], return_to_origin=False,
            selected_transport_option_ids=["mode:walking"],
        ),
    )

    assert body["route"]["travel_mode"] == "walking"
    assert fake.preview_calls[0]["travel_mode"] == "walking"
    assert body["fuel"]["amount"] is None
    assert body["budget"]["category_totals"]["transportation"] == "0.00"


def test_conflicting_walking_and_personal_choices_need_review_without_provider(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    fake = FakeOSRMClient(error=AssertionError("Conflicting modes need selection review"))
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(
            destination["destination_id"],
            selected_transport_option_ids=["mode:personal_vehicle", "mode:walking"],
        ),
    )

    assert body["route"]["status"] == "needs_review"
    assert body["route"]["summary"] is None
    assert fake.preview_calls == fake.optimize_calls == []


def test_explicit_optimization_preserves_origin_and_original_selection_order(client) -> None:
    admin = register(client, admin=True)
    first = create_destination(client, admin, name="Route First Stop")
    second = create_destination(client, admin, name="Route Second Stop", lat=7.4, lng=125.7)
    third = create_destination(client, admin, name="Route Third Stop", lat=7.5, lng=125.8)
    ids = [first["destination_id"], second["destination_id"], third["destination_id"]]
    fake = FakeOSRMClient(
        optimize_result=route_result(10000, 12000, 13000, 15000, stop_order=[0, 3, 1, 2]),
    )
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(
            first["destination_id"], destination_ids=ids,
            route_preferences={"optimize_order": True, "road_access_confirmed": True},
        ),
    )

    assert body["state"]["destination_ids"] == ids
    assert body["route"]["order_strategy"] == "optimize"
    assert body["route"]["status"] == "calculated"
    assert [stop["destination_id"] for stop in body["route"]["summary"]["stops"]] == [
        None, third["destination_id"], first["destination_id"], second["destination_id"], None
    ]
    assert fake.optimize_calls[0]["preserve_first"] is True
    assert fake.optimize_calls[0]["roundtrip"] is True
    assert fake.preview_calls == []
    assert Decimal(body["fuel"]["distance_km"]) == Decimal("50")


def test_optimizer_result_cannot_move_requested_origin_and_price_different_journey(client) -> None:
    admin = register(client, admin=True)
    first = create_destination(client, admin, name="Origin Safety Stop A")
    second = create_destination(client, admin, name="Origin Safety Stop B", lat=7.4, lng=125.7)
    ids = [first["destination_id"], second["destination_id"]]
    fake = FakeOSRMClient(
        optimize_result=route_result(10000, 20000, 30000, stop_order=[1, 0, 2]),
    )
    override_route_service(client, fake)

    body = post_preview(
        client, register(client),
        routing_request(
            first["destination_id"], destination_ids=ids,
            route_preferences={"optimize_order": True, "road_access_confirmed": True},
        ),
    )

    assert body["state"]["destination_ids"] == ids
    assert body["route"]["status"] == "calculated"
    assert body["route"]["summary"]["route_provider"] == "haversine"
    assert body["route"]["summary"]["stops"][0]["destination_id"] is None
    assert body["route"]["summary"]["stops"][-1]["destination_id"] is None
    assert body["fuel"]["amount"] is None
    assert body["budget"]["total_estimate"] is None
    assert fake.optimize_calls[0]["preserve_first"] is True


def test_provider_total_disagreeing_with_legs_cannot_supply_complete_fuel_budget(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    inconsistent = OSRMRouteResult(
        total_distance_meters=99999, total_duration_seconds=1200,
        legs=[
            OSRMLeg(distance_meters=10000, duration_seconds=600),
            OSRMLeg(distance_meters=20000, duration_seconds=600),
        ],
    )
    fake = FakeOSRMClient(preview_result=inconsistent)
    override_route_service(client, fake)

    body = post_preview(client, register(client), routing_request(destination["destination_id"]))

    assert body["fuel"]["status"] == "unavailable"
    assert body["fuel"]["amount"] is None
    assert body["budget"]["completeness"] == "partial"
    assert body["budget"]["total_estimate"] is None
    assert body["budget"]["remaining_budget"] is None
    assert body["budget"]["category_totals"]["transportation"] == "0.00"


def test_configured_route_limit_retains_choices_and_budget_without_provider_work(client, monkeypatch) -> None:
    admin = register(client, admin=True)
    first = create_destination(client, admin, name="Limited Stop A")
    second = create_destination(client, admin, name="Limited Stop B", lat=7.4, lng=125.7)
    fake = FakeOSRMClient(error=AssertionError("Configured stop limit must precede provider work"))
    override_route_service(client, fake)
    monkeypatch.setenv("ROUTE_MAX_DESTINATIONS", "1")
    get_settings.cache_clear()
    ids = [first["destination_id"], second["destination_id"]]

    body = post_preview(
        client, register(client),
        routing_request(first["destination_id"], destination_ids=ids),
    )

    assert body["state"]["destination_ids"] == ids
    assert {item["destination_id"] for item in body["destinations"]} == set(ids)
    assert body["transport_options"]
    assert body["budget"]["priced_subtotal"] == "300.00"
    assert body["route"]["status"] == "needs_review"
    assert body["route"]["summary"] is None
    assert body["fuel"]["amount"] is None
    assert fake.preview_calls == fake.optimize_calls == []


@pytest.mark.parametrize(
    "invalid",
    [
        {"kilometers_per_liter": "0"},
        {"kilometers_per_liter": "-1"},
        {"kilometers_per_liter": "NaN"},
        {"price_per_liter": "0"},
        {"price_per_liter": "-1"},
        {"price_per_liter": "NaN"},
        {"price_per_liter": "Infinity"},
        {"vehicle_count": 0},
        {"parking_amount": "-1.00"},
        {"parking_amount": "NaN"},
        {"distance_km": "1"},
        {"amount": "0.01"},
    ],
)
def test_invalid_fuel_inputs_and_forged_distance_or_total_are_rejected(client, invalid) -> None:
    response = client.post(
        "/api/v1/planning/preview", headers=register(client),
        json=routing_request(1, fuel_assumptions=fuel_assumptions(**invalid)),
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_requested_route_is_read_only_and_uses_no_ai_or_live_traffic(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    user = register(client)
    fake = FakeOSRMClient(preview_result=route_result(10000, 20000))
    override_route_service(client, fake)

    def unexpected_provider():
        raise AssertionError("Road preview must not request Groq or Google Routes.")

    for provider in (get_groq_client, get_google_routes_client):
        client.app.dependency_overrides[provider] = unexpected_provider
    statements = []

    def record_statement(connection, cursor, statement, parameters, context, executemany):
        statements.append(statement.strip().split(maxsplit=1)[0].upper())

    event.listen(Engine, "before_cursor_execute", record_statement)
    try:
        body = post_preview(client, user, routing_request(destination["destination_id"]))
    finally:
        event.remove(Engine, "before_cursor_execute", record_statement)

    assert body["route"]["status"] == "calculated"
    assert "SELECT" in statements
    assert not {"INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP"}.intersection(statements)


def test_route_limit_is_per_user_and_cost_only_requests_do_not_consume_it(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    user = register(client)
    limiter = PlanningRouteLimiter(limit=2, window_seconds=60)
    client.app.dependency_overrides[get_planning_route_limiter] = lambda: limiter
    cost_request = preview_request(destination["destination_id"])
    # Use the real routing dependency, but incomplete coordinates prevent any
    # external call. Limiting happens before provider work is attempted.
    request = routing_request(destination["destination_id"], origin={"label": "Davao City"})

    for _ in range(4):
        assert post_preview(client, user, cost_request)["route"]["status"] == "not_requested"
    for _ in range(2):
        assert post_preview(client, user, request)["route"]["status"] == "needs_details"

    blocked = client.post("/api/v1/planning/preview", headers=user, json=request)

    assert blocked.status_code == 429
    assert blocked.json()["error"]["code"] == "planning_route_rate_limit_exceeded"
    assert post_preview(client, user, cost_request)["route"]["status"] == "not_requested"
    assert post_preview(client, admin, request)["route"]["status"] == "needs_details"


def test_route_limit_window_expires_without_sleep(monkeypatch) -> None:
    clock = {"now": 100.0}
    monkeypatch.setattr(provider_usage, "monotonic", lambda: clock["now"])
    limiter = PlanningRouteLimiter(limit=1, window_seconds=60)
    limiter.check(user_id=1)
    clock["now"] = 159.999

    with pytest.raises(LakbayAPIError) as rejected:
        limiter.check(user_id=1)
    assert rejected.value.code == "planning_route_rate_limit_exceeded"
    clock["now"] = 160.0
    limiter.check(user_id=1)

    with pytest.raises(LakbayAPIError) as new_window_rejected:
        limiter.check(user_id=1)
    assert new_window_rejected.value.code == "planning_route_rate_limit_exceeded"
