from app.features.geo_analytics.dependencies import GeoGroupLimiter, get_geo_group_limiter
from app.integrations.osrm.client import get_osrm_client
from app.integrations.osrm.errors import OSRMClientError
from app.integrations.osrm.schemas import OSRMLeg, OSRMRouteResult, OSRMStep


BASE_DESTINATION = {
    "name": "Group Stop A",
    "description": "A destination for grouping tests.",
    "district": "Davao City",
    "location": "Davao City",
    "category": "park",
    "vibes": "relaxed",
    "activities": "walking",
    "lat": 7.0644,
    "lng": 125.6078,
    "estimated_cost": "100.00",
    "budget_class": "budget",
    "difficulty_level": "easy",
    "stay_duration_type": "short",
    "is_kid_friendly": True,
}


class FakeOSRM:
    def __init__(self, *, fail: bool = False, leg_seconds: int = 600) -> None:
        self.fail = fail
        self.leg_seconds = leg_seconds
        self.calls = 0

    async def matrix(self, **kwargs):
        # Without a table, group routes use OSRM Trip as these tests expect.
        raise OSRMClientError("This fake has no travel-time table.")

    async def optimize_route(self, *, coordinates, **kwargs):
        self.calls += 1
        if self.fail:
            raise OSRMClientError("OSRM unavailable")
        count = len(coordinates) - 1
        return OSRMRouteResult(
            total_distance_meters=count * 3000,
            total_duration_seconds=count * self.leg_seconds,
            legs=[
                OSRMLeg(
                    distance_meters=3000,
                    duration_seconds=self.leg_seconds,
                    steps=[OSRMStep(
                        distance_meters=3000,
                        duration_seconds=self.leg_seconds,
                        maneuver_type="turn",
                        modifier="right",
                        road_name="Test Road",
                    )],
                )
                for _ in range(count)
            ],
            stop_order=list(range(len(coordinates))),
            polyline="encoded-route",
        )


def user_headers(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Geo User",
            "email": "geo-user@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def admin_headers(client):
    response = client.post(
        "/api/v1/auth/register/admin",
        json={
            "full_name": "Geo Admin",
            "email": "geo-admin@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "admin_registration_code": "admin-test-code",
        },
    )
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def destinations(client, *, verified: bool = False):
    headers = admin_headers(client)
    records = []
    for name, lat, lng, category in (
        ("Group Stop A", 7.0644, 125.6078, "park"),
        ("Group Stop B", 7.0744, 125.6178, "park"),
        ("Group Stop C", 7.0844, 125.6278, "beach"),
        ("Far Stop", 6.50, 126.00, "park"),
    ):
        arrival = {
            "arrival_lat": lat,
            "arrival_lng": lng,
            "arrival_source_url": "https://example.com/arrival",
            "arrival_verified_at": "2026-11-03T00:00:00Z",
            "route_ready": True,
        } if verified else {}
        response = client.post(
            "/api/v1/destinations",
            headers=headers,
            json={
                **BASE_DESTINATION, "name": name, "lat": lat, "lng": lng,
                "category": category, **arrival,
            },
        )
        assert response.status_code == 201
        records.append(response.json())
    return [item["destination_id"] for item in records]


def test_grouping_requires_authentication(client):
    response = client.post(
        "/api/v1/geo-analytics/destination-groups",
        json={"destination_ids": [1, 2]},
    )
    assert response.status_code == 401


def test_grouping_returns_nearby_ranked_groups_with_route_facts(client):
    ids = destinations(client)
    fake = FakeOSRM()
    client.app.dependency_overrides[get_osrm_client] = lambda: fake
    response = client.post(
        "/api/v1/geo-analytics/destination-groups",
        headers=user_headers(client),
        json={
            "destination_ids": ids,
            "group_size": 2,
            "max_groups": 2,
            "max_separation_km": 10,
            "max_destination_cost": "250.00",
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["candidates_considered"] == 3
    assert len(body["groups"]) == 2
    assert body["groups"][0]["destination_ids"] == ids[:2]
    assert all(ids[3] not in group["destination_ids"] for group in body["groups"])
    assert all(group["route_provider"] == "osrm" for group in body["groups"])
    assert all(group["route_distance_km"] == "3.00" for group in body["groups"])
    assert all(group["estimated_destination_cost"] == "200.00" for group in body["groups"])
    route = body["groups"][0]["route"]
    assert route["route_provider"] == "osrm"
    assert route["total_distance_km"] == body["groups"][0]["route_distance_km"]
    assert route["stops"][0]["destination_id"] == ids[0]
    assert route["polyline"] == "encoded-route"
    assert route["polyline_encoding"] == "polyline5"
    assert route["arrival_points_verified"] is False
    assert route["legs"][0]["steps"] == []
    assert any("planning preview" in warning for warning in route["warnings"])
    assert body["groups"][0]["scores"]["budget_fit"] == 20.0
    assert "No saved preferences" in " ".join(body["warnings"])
    assert fake.calls == 3


def test_grouping_exposes_directions_for_verified_arrival_points(client):
    ids = destinations(client, verified=True)
    client.app.dependency_overrides[get_osrm_client] = lambda: FakeOSRM()
    response = client.post(
        "/api/v1/geo-analytics/destination-groups",
        headers=user_headers(client),
        json={"destination_ids": ids[:2], "group_size": 2},
    )
    assert response.status_code == 200
    group = response.json()["groups"][0]
    assert group["route_order"] == ids[:2]
    assert group["route"]["arrival_points_verified"] is True
    assert group["route"]["stops"][0]["coordinate_basis"] == "verified_arrival"
    assert group["route"]["legs"][0]["steps"][0]["instruction"] == (
        "Turn right onto Test Road"
    )


def test_grouping_returns_no_groups_when_cost_limit_is_too_low(client):
    ids = destinations(client)
    response = client.post(
        "/api/v1/geo-analytics/destination-groups",
        headers=user_headers(client),
        json={
            "destination_ids": ids[:3],
            "group_size": 2,
            "max_destination_cost": "150.00",
        },
    )
    assert response.status_code == 200
    assert response.json()["groups"] == []
    assert response.json()["candidates_considered"] == 0


def test_grouping_excludes_routes_over_duration_limit(client):
    ids = destinations(client)
    client.app.dependency_overrides[get_osrm_client] = lambda: FakeOSRM(
        leg_seconds=3600
    )
    response = client.post(
        "/api/v1/geo-analytics/destination-groups",
        headers=user_headers(client),
        json={"destination_ids": ids[:2], "group_size": 2, "max_route_minutes": 30},
    )
    assert response.status_code == 200
    assert response.json()["groups"] == []
    assert response.json()["candidates_considered"] == 1


def test_grouping_exposes_haversine_fallback(client):
    ids = destinations(client)
    client.app.dependency_overrides[get_osrm_client] = lambda: FakeOSRM(fail=True)
    response = client.post(
        "/api/v1/geo-analytics/destination-groups",
        headers=user_headers(client),
        json={"destination_ids": ids[:2], "group_size": 2},
    )
    assert response.status_code == 200
    group = response.json()["groups"][0]
    assert group["is_route_estimated"] is True
    assert group["route_provider"] == "haversine"
    assert any("Haversine" in warning for warning in group["warnings"])
    assert group["route"]["is_estimated"] is True
    assert group["route"]["polyline"] is None
    assert group["route"]["legs"][0]["steps"] == []


def test_grouping_validates_duplicate_and_missing_ids(client):
    ids = destinations(client)
    headers = user_headers(client)
    duplicate = client.post(
        "/api/v1/geo-analytics/destination-groups",
        headers=headers,
        json={"destination_ids": [ids[0], ids[0]]},
    )
    assert duplicate.status_code == 422
    missing = client.post(
        "/api/v1/geo-analytics/destination-groups",
        headers=headers,
        json={"destination_ids": [ids[0], 99999], "group_size": 2},
    )
    assert missing.status_code == 404
    assert missing.json()["error"]["details"]["destination_ids"] == [99999]


def test_grouping_reads_saved_preferences_without_recreating_them(client):
    ids = destinations(client)
    headers = user_headers(client)
    saved = client.post(
        "/api/v1/recommendations",
        headers=headers,
        json={"preferred_categories": ["park"], "limit": 5},
    )
    assert saved.status_code == 201
    preference_id = saved.json()["preference_signal_id"]
    client.app.dependency_overrides[get_osrm_client] = lambda: FakeOSRM()
    grouped = client.post(
        "/api/v1/geo-analytics/destination-groups",
        headers=headers,
        json={"destination_ids": ids[:3], "group_size": 2},
    )
    assert grouped.status_code == 200
    assert len(grouped.json()["groups"]) == 1
    assert grouped.json()["groups"][0]["destination_ids"] == ids[:2]
    latest = client.get("/api/v1/recommendations/preferences/latest", headers=headers)
    assert latest.json()["preference_signal_id"] == preference_id


def test_grouping_limits_expensive_requests_per_user(client):
    ids = destinations(client)
    headers = user_headers(client)
    limiter = GeoGroupLimiter(limit=1)
    client.app.dependency_overrides[get_geo_group_limiter] = lambda: limiter
    client.app.dependency_overrides[get_osrm_client] = lambda: FakeOSRM()
    payload = {"destination_ids": ids[:2], "group_size": 2}
    first = client.post(
        "/api/v1/geo-analytics/destination-groups", headers=headers, json=payload
    )
    second = client.post(
        "/api/v1/geo-analytics/destination-groups", headers=headers, json=payload
    )
    assert first.status_code == 200
    assert second.status_code == 429
    assert second.json()["error"]["code"] == "geo_group_rate_limit_exceeded"
