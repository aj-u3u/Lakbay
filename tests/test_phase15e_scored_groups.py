"""The AI generation contract uses real Phase 15B scores for selected IDs."""

import json
from decimal import Decimal

from app.features.ai.router import get_ai_itinerary_route_service
from app.features.geo_analytics.dependencies import GeoGroupLimiter
from app.features.routes.schemas import RouteLeg, RouteStop, RouteSummaryResponse
from app.integrations.groq.client import get_groq_client
from tests.test_phase5_ai_itineraries import (
    FakeGroqClient, configure_ai, create_destination, create_transportation,
    valid_ai_response,
)
from tests.test_planning_ai_save import _planning_request
from tests.test_planning_preview import register


class FakeRoutes:
    def __init__(self) -> None:
        self.preview_calls = 0
        self.group_calls = 0

    async def preview_route(self, data):
        self.preview_calls += 1
        origin = data.origin
        stops = [RouteStop(
            order=1, destination_id=None, name=origin.label or "Origin",
            lat=origin.lat, lng=origin.lng, is_origin=True,
            coordinate_basis="origin",
        )]
        stops.extend(RouteStop(
            order=index + 2, destination_id=destination_id,
            name=f"Stop {destination_id}", lat=7.07, lng=125.61,
        ) for index, destination_id in enumerate(data.destination_ids))
        return _summary(data.travel_mode, stops)

    async def optimize_route(self, data):
        self.group_calls += 1
        stops = [RouteStop(
            order=index + 1, destination_id=destination_id,
            name=f"Stop {destination_id}", lat=7.07, lng=125.61,
        ) for index, destination_id in enumerate(data.destination_ids)]
        return _summary(data.travel_mode, stops)


def _summary(mode, stops):
    legs = [RouteLeg(
        order=index + 1,
        from_destination_id=stops[index].destination_id,
        to_destination_id=stops[index + 1].destination_id,
        from_name=stops[index].name,
        to_name=stops[index + 1].name,
        distance_km=Decimal("2.00"),
        duration_minutes=10,
        is_estimated=True,
    ) for index in range(len(stops) - 1)]
    return RouteSummaryResponse(
        travel_mode=mode, route_provider="haversine", is_estimated=True,
        total_distance_km=Decimal(2 * len(legs)),
        total_duration_minutes=10 * len(legs),
        stops=stops, legs=legs, arrival_points_verified=False,
        warnings=["Route is estimated."],
    )


def test_generation_passes_scored_groups_and_selected_recommendations(client, monkeypatch):
    configure_ai(monkeypatch)
    admin = register(client, admin=True)
    first = create_destination(client, admin)
    second = create_destination(client, admin, name="Another Beach")
    unselected = create_destination(client, admin, name="Unselected Beach")
    first_id, second_id = first["destination_id"], second["destination_id"]
    transport = create_transportation(
        client, destination_id=first_id, headers=admin,
        route_to=first["name"], charging_unit="per_person",
    )
    payload = _planning_request(first_id, transport["transportation_id"])
    payload["destination_ids"].append(second_id)
    payload["planning_state"]["destination_ids"].append(second_id)
    payload["interests"] = ["beach"]
    payload["planning_state"]["cost_allowances"].append({
        "category": "destination", "destination_id": second_id, "amount": "100.00",
    })
    output = json.loads(valid_ai_response(
        destination_id=first_id, transportation_id=transport["transportation_id"],
        day_count=1,
    ))
    for option in output["options"]:
        option["days"][0]["activities"].append({
            "time": "11:00", "title": "Second beach", "description": "Visit the second beach.",
            "destination_id": second_id, "estimated_cost": "100.00",
        })
    fake_ai = FakeGroqClient([json.dumps(output)])
    routes = FakeRoutes()
    client.app.dependency_overrides[get_groq_client] = lambda: fake_ai
    client.app.dependency_overrides[get_ai_itinerary_route_service] = lambda: routes
    limiter = GeoGroupLimiter(limit=1)
    monkeypatch.setattr("app.features.ai.geo_context.get_geo_group_limiter", lambda: limiter)
    user = register(client)

    response = client.post(
        "/api/v1/ai/itineraries/generate", headers=user, json=payload,
    )

    assert response.status_code == 200, response.text
    context = response.json()["geo_analytics_context"]
    assert context["grouping_status"] == "scored"
    group = context["destination_groups"][0]
    assert group["source"] == "phase15b_destination_groups"
    assert group["destination_ids"] == [first_id, second_id]
    assert isinstance(group["score"], (int, float))
    assert group["is_route_estimated"] is True
    assert group["route_scope"] == "between_group_destinations_without_trip_origin"
    assert {item["destination_id"] for item in context["top_recommendations"]} == {first_id, second_id}
    assert unselected["destination_id"] not in {
        item["destination_id"] for item in context["top_recommendations"]
    }
    assert routes.preview_calls == 1
    assert routes.group_calls == 1
    prompt = json.loads(fake_ai.calls[0]["messages"][1]["content"])
    assert prompt["geo_analytics_context"] == context
    assert {activity["destination_id"] for activity in response.json()["options"][0]["days"][0]["activities"]} == {first_id, second_id}

    limited = client.post(
        "/api/v1/ai/itineraries/generate", headers=user, json=payload,
    )
    assert limited.status_code == 429
    assert limited.json()["error"]["code"] == "geo_group_rate_limit_exceeded"
    assert len(fake_ai.calls) == 1
