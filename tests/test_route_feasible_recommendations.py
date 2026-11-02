import asyncio
from datetime import datetime, timezone
from decimal import Decimal

import pytest

from app.features.destinations.models import Destination
from app.features.recommendations.service import RecommendationService, _confirms_candidate_route
from app.features.routes.schemas import (
    RouteCoordinate, RouteLeg, RouteStop, RouteSummaryResponse,
)
from app.integrations.osrm.client import _require_near_route_waypoints
from app.integrations.osrm.errors import OSRMRouteNotFoundError


def _confirmed_route() -> RouteSummaryResponse:
    return RouteSummaryResponse(
        travel_mode="driving",
        route_provider="osrm",
        is_estimated=False,
        arrival_points_verified=True,
        total_distance_km=Decimal("12.00"),
        total_duration_minutes=20,
        stops=[
            RouteStop(order=1, destination_id=None, name="Origin", lat=7.0731,
                      lng=125.6128, is_origin=True, coordinate_basis="origin"),
            RouteStop(order=2, destination_id=42, name="Beach", lat=6.951,
                      lng=126.25, coordinate_basis="verified_arrival"),
        ],
        legs=[
            RouteLeg(order=1, from_destination_id=None, to_destination_id=42,
                     from_name="Origin", to_name="Beach", distance_km=Decimal("12.00"),
                     duration_minutes=20, is_estimated=False),
        ],
    )


def _qualifies(route: RouteSummaryResponse) -> bool:
    destination = Destination(destination_id=42, arrival_lat=6.951, arrival_lng=126.25)
    origin = RouteCoordinate(lat=7.0731, lng=125.6128)
    return _confirms_candidate_route(route, destination, origin, "driving")


def test_route_feasible_recommendation_requires_matching_trip() -> None:
    assert _qualifies(_confirmed_route())


@pytest.mark.parametrize("change", [
    lambda route: setattr(route.stops[0], "lat", 7.5),
    lambda route: setattr(route.stops[1], "lng", 126.5),
    lambda route: setattr(route.stops[1], "destination_id", 99),
    lambda route: setattr(route.legs[0], "to_destination_id", 99),
    lambda route: setattr(route, "travel_mode", "walking"),
    lambda route: setattr(route, "total_distance_km", Decimal("20.00")),
    lambda route: setattr(route, "total_duration_minutes", 35),
    lambda route: setattr(route, "is_estimated", True),
])
def test_route_feasible_recommendation_rejects_mismatched_trip(change) -> None:
    route = _confirmed_route()
    change(route)
    assert not _qualifies(route)


def test_equal_preference_matches_use_confirmed_travel_time() -> None:
    destinations = [
        Destination(
            destination_id=index, name=f"Beach {index}", category="beach",
            estimated_cost=Decimal("0"), route_ready=True, arrival_lat=6.95 + index / 1000,
            arrival_lng=126.25, arrival_source_url="https://example.org/gate",
            arrival_verified_at=datetime(2026, 10, 29, tzinfo=timezone.utc),
        )
        for index in (1, 2)
    ]

    class Catalog:
        async def list_active_destinations(self):
            return destinations

        async def list_popularity(self):
            return {}

    class Routes:
        async def preview_route(self, request):
            destination_id = request.destination_ids[0]
            destination = destinations[destination_id - 1]
            route = _confirmed_route()
            route.stops[1].destination_id = destination_id
            route.stops[1].lat = destination.arrival_lat
            route.stops[1].lng = destination.arrival_lng
            route.legs[0].to_destination_id = destination_id
            route.total_duration_minutes = 35 if destination_id == 1 else 20
            route.legs[0].duration_minutes = route.total_duration_minutes
            return route

    service = RecommendationService(None)
    service.recommendations = Catalog()
    ranked, total, reason = asyncio.run(service.rank_planning_candidates(
        interests=["beach"], traveler_count=1,
        origin=RouteCoordinate(lat=7.0731, lng=125.6128),
        travel_mode="driving", route_service=Routes(), limit=2,
    ))
    assert [item.destination_id for item in ranked] == [2, 1]
    assert total == 2
    assert reason is None


def test_osrm_requires_nearby_snapped_waypoints() -> None:
    _require_near_route_waypoints(
        {"waypoints": [{"distance": 0.0}, {"distance": 249.0}]}, 2,
    )
    with pytest.raises(OSRMRouteNotFoundError):
        _require_near_route_waypoints(
            {"waypoints": [{"distance": 0.0}, {"distance": 1250.0}]}, 2,
        )
    with pytest.raises(OSRMRouteNotFoundError):
        _require_near_route_waypoints({"waypoints": [{"distance": 0.0}]}, 2)
