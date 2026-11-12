"""Admin edits must reach traveler reads, pin ranking, routes and Groq context."""

import json

import pytest

from app.integrations.groq.client import get_groq_client
from app.integrations.osrm.client import get_osrm_client
from app.integrations.osrm.schemas import OSRMLeg, OSRMRouteResult
from tests.test_phase5_ai_itineraries import (
    FakeGroqClient,
    admin_headers,
    configure_ai,
    create_accommodation,
    create_destination,
    create_transportation,
    itinerary_request,
    user_headers,
    valid_ai_response,
)
from tests.test_phase6_routes import FakeOSRMClient
from tests.test_planning_routes import override_route_service
from tests.test_top_places_scoring import TableOSRM


class CatalogOSRM(FakeOSRMClient):
    def __init__(self):
        super().__init__(preview_result=OSRMRouteResult(
            total_distance_meters=4000,
            total_duration_seconds=600,
            legs=[OSRMLeg(distance_meters=4000, duration_seconds=600)],
        ))
        self.table_points = []

    async def table(self, **kwargs):
        self.table_points = kwargs["destinations"]
        return await TableOSRM().table(**kwargs)


@pytest.mark.parametrize("known_units", [True, False])
def test_admin_edits_reach_catalog_ranking_preview_and_generation(client, monkeypatch, known_units):
    configure_ai(monkeypatch)
    admin = admin_headers(client)
    traveler = user_headers(client)
    destination = create_destination(client, headers=admin, name="Original Beach")
    destination_id = destination["destination_id"]
    stay = create_accommodation(
        client, headers=admin, destination_id=destination_id,
        currency="PHP", charging_unit="per_room_per_night" if known_units else None,
    )
    ride = create_transportation(
        client, headers=admin, destination_id=destination_id,
        currency="PHP", charging_unit="per_person" if known_units else None,
    )
    edits = {
        "name": "Reviewed Beach", "lat": 7.08, "lng": 125.62,
        "estimated_cost": "350.25", "entrance_fee": "PHP 200 per adult",
        "operating_hours": "08:00-16:00; confirm closures before travel",
        "best_time_to_visit": "Weekday mornings",
        "how_to_get_there": "Use the coastal access road; confirm the final approach.",
        "estimated_travel_time": "About one hour from the city, traffic dependent",
        "travel_notes": "Confirm access and permits with the operator.",
        "what_to_bring": "Water and sun protection",
    }
    path = f"/api/v1/destinations/{destination_id}"
    assert client.patch(path, headers=traveler, json=edits).status_code == 403
    updated = client.patch(path, headers=admin, json=edits)
    assert updated.status_code == 200
    for key, value in edits.items():
        assert updated.json()[key] == value
    assert updated.json()["route_ready"] is False
    assert updated.json()["arrival_lat"] is None
    assert client.patch(
        f"/api/v1/accommodations/{stay['accommodation_id']}",
        headers=admin, json={"price": "2450.50"},
    ).status_code == 200
    assert client.patch(
        f"/api/v1/transportations/{ride['transportation_id']}",
        headers=admin, json={"price": "320.25"},
    ).status_code == 200

    detail = client.get(path).json()
    catalog = client.get("/api/v1/destinations").json()
    assert next(row for row in catalog if row["destination_id"] == destination_id) == detail
    for key, value in edits.items():
        assert detail[key] == value
    for kind, id_key, record, price in (
        ("accommodations", "accommodation_id", stay, "2450.50"),
        ("transportations", "transportation_id", ride, "320.25"),
    ):
        [rate] = client.get(f"{path}/{kind}").json()
        assert rate[id_key] == record[id_key]
        assert rate["price"] == price
        assert rate["currency"] == "PHP"
        assert rate["charging_unit"] == record["charging_unit"]

    osrm = CatalogOSRM()
    client.app.dependency_overrides[get_osrm_client] = lambda: osrm
    override_route_service(client, osrm)
    origin = {"label": "Davao City", "lat": 7.07, "lng": 125.61}
    top = client.post(
        "/api/v1/recommendations/top-places", headers=traveler,
        json={"origin": origin, "interests": ["beach"], "total_budget": "5000.00"},
    )
    assert top.status_code == 201
    [item] = top.json()["items"]
    assert item["destination_id"] == destination_id
    assert item["name"] == edits["name"]
    assert item["estimated_cost"] == edits["estimated_cost"]
    assert item["travel_basis"] == "approximate_location"
    assert item["route_verified"] is False
    assert (osrm.table_points[0].lat, osrm.table_points[0].lng) == (7.08, 125.62)

    preview = client.post(
        "/api/v1/planning/preview", headers=traveler,
        json={"state": {
            "origin": origin, "destination_ids": [destination_id],
            "total_budget": "5000.00", "traveler_count": 1,
            "day_count": 1, "night_count": 0, "return_to_origin": False,
            "selected_transport_option_ids": ["mode:personal_vehicle"],
            "route_preferences": {"road_access_confirmed": True},
            "cost_allowances": [{
                "category": "destination", "destination_id": destination_id,
                "amount": "350.25",
            }],
        }},
    )
    assert preview.status_code == 200
    [selected] = preview.json()["destinations"]
    assert selected["catalog_estimated_cost"] == "350.25"
    assert selected["entrance_fee_description"] == edits["entrance_fee"]
    summary = preview.json()["route"]["summary"]
    stop = next(stop for stop in summary["stops"] if stop["destination_id"] == destination_id)
    assert (stop["lat"], stop["lng"]) == (7.08, 125.62)
    assert stop["coordinate_basis"] == "attraction"
    assert summary["arrival_points_verified"] is False
    assert all(not leg["steps"] for leg in summary["legs"])

    groq = FakeGroqClient([valid_ai_response(
        destination_id=destination_id, accommodation_id=stay["accommodation_id"],
        transportation_id=ride["transportation_id"],
    )])
    client.app.dependency_overrides[get_groq_client] = lambda: groq
    generated = client.post(
        "/api/v1/ai/itineraries/generate", headers=traveler,
        json=itinerary_request(
            destination_id, accommodation_ids=[stay["accommodation_id"]],
            transportation_ids=[ride["transportation_id"]], allow_fallback=False,
        ),
    )
    assert generated.status_code == 200
    assert generated.json()["options"]
    prompt = json.loads(groq.calls[0]["messages"][1]["content"])
    [place] = prompt["catalog"]["destinations"]
    for key, value in edits.items():
        assert place[key] == value
    assert place["route_ready"] is False
    assert place["arrival_lat"] is None
    [prompt_stay] = prompt["catalog"]["accommodations"]
    [prompt_ride] = prompt["catalog"]["transportations"]
    assert prompt_stay["price"] == "2450.50"
    assert prompt_ride["price"] == "320.25"
    assert prompt_stay["currency"] == prompt_ride["currency"] == "PHP"
    assert prompt_stay["charging_unit"] == stay["charging_unit"]
    assert prompt_ride["charging_unit"] == ride["charging_unit"]
