from app.integrations.google_routes.client import get_google_routes_client
from app.integrations.google_routes.errors import GoogleRoutesClientError
from app.integrations.google_routes.schemas import GoogleRouteLeg, GoogleRouteResult
from app.integrations.osrm.client import get_osrm_client
from app.integrations.osrm.errors import OSRMClientError
from app.integrations.osrm.schemas import OSRMLeg, OSRMRouteResult


DESTINATION_A = {
    "name": "Route Stop A",
    "description": "A route test destination.",
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
}
DESTINATION_B = {
    **DESTINATION_A,
    "name": "Route Stop B",
    "lat": 7.0994,
    "lng": 125.6197,
}
DESTINATION_C = {
    **DESTINATION_A,
    "name": "Route Stop C",
    "lat": 7.1907,
    "lng": 125.4553,
}


class FakeOSRMClient:
    def __init__(
        self,
        *,
        preview_result: OSRMRouteResult | None = None,
        optimize_result: OSRMRouteResult | None = None,
        error: Exception | None = None,
    ) -> None:
        self.preview_result = preview_result
        self.optimize_result = optimize_result
        self.error = error
        self.preview_calls = []
        self.optimize_calls = []

    async def preview_route(self, **kwargs) -> OSRMRouteResult:
        self.preview_calls.append(kwargs)

        if self.error is not None:
            raise self.error

        return self.preview_result or OSRMRouteResult(
            total_distance_meters=0,
            total_duration_seconds=0,
            legs=[],
        )

    async def optimize_route(self, **kwargs) -> OSRMRouteResult:
        self.optimize_calls.append(kwargs)

        if self.error is not None:
            raise self.error

        return self.optimize_result or OSRMRouteResult(
            total_distance_meters=0,
            total_duration_seconds=0,
            legs=[],
            stop_order=[],
        )


class FakeGoogleRoutesClient:
    is_configured = True

    def __init__(
        self,
        *,
        result: GoogleRouteResult | None = None,
        error: Exception | None = None,
    ) -> None:
        self.result = result
        self.error = error
        self.calls = []

    async def compute_route(self, **kwargs) -> GoogleRouteResult:
        self.calls.append(kwargs)

        if self.error is not None:
            raise self.error

        return self.result or GoogleRouteResult(
            total_distance_meters=0,
            total_duration_seconds=0,
            total_static_duration_seconds=0,
            legs=[],
        )


def admin_headers(client) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register/admin",
        json={
            "full_name": "Route Admin",
            "email": "route-admin@example.com",
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
            "full_name": "Route User",
            "email": "route-user@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def create_destination(client, headers: dict[str, str], payload: dict) -> dict:
    response = client.post(
        "/api/v1/destinations",
        headers=headers,
        json=payload,
    )

    assert response.status_code == 201

    return response.json()


def create_route_destinations(client) -> tuple[dict, dict, dict]:
    headers = admin_headers(client)

    return (
        create_destination(client, headers, DESTINATION_A),
        create_destination(client, headers, DESTINATION_B),
        create_destination(client, headers, DESTINATION_C),
    )


def test_route_preview_requires_authentication(client) -> None:
    response = client.post(
        "/api/v1/routes/preview",
        json={"destination_ids": [1], "travel_mode": "driving"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_route_preview_uses_osrm_for_driving(client) -> None:
    destination_a, destination_b, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(
        preview_result=OSRMRouteResult(
            total_distance_meters=12000,
            total_duration_seconds=1500,
            legs=[
                OSRMLeg(distance_meters=12000, duration_seconds=1500),
            ],
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={
            "destination_ids": [
                destination_a["destination_id"],
                destination_b["destination_id"],
            ],
            "travel_mode": "driving",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "osrm"
    assert body["is_estimated"] is False
    assert body["total_distance_km"] == "12.00"
    assert body["total_duration_minutes"] == 25
    assert [stop["destination_id"] for stop in body["stops"]] == [
        destination_a["destination_id"],
        destination_b["destination_id"],
    ]
    assert body["legs"][0]["distance_km"] == "12.00"
    assert fake_osrm.preview_calls[0]["travel_mode"] == "driving"


def test_route_preview_uses_google_live_traffic_when_requested(client) -> None:
    destination_a, destination_b, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(error=AssertionError("OSRM should not be called."))
    fake_google = FakeGoogleRoutesClient(
        result=GoogleRouteResult(
            total_distance_meters=12000,
            total_duration_seconds=2400,
            total_static_duration_seconds=1500,
            legs=[
                GoogleRouteLeg(
                    distance_meters=12000,
                    duration_seconds=2400,
                    static_duration_seconds=1500,
                ),
            ],
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm
    client.app.dependency_overrides[get_google_routes_client] = lambda: fake_google

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={
            "destination_ids": [
                destination_a["destination_id"],
                destination_b["destination_id"],
            ],
            "travel_mode": "driving",
            "use_live_traffic": True,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "google_routes"
    assert body["is_estimated"] is False
    assert body["total_duration_minutes"] == 40
    assert body["traffic"]["normal_duration_minutes"] == 25
    assert body["traffic"]["delay_minutes"] == 15
    assert body["traffic"]["traffic_level"] == "moderate"
    assert body["legs"][0]["traffic_delay_minutes"] == 15
    assert fake_osrm.preview_calls == []
    assert fake_google.calls[0]["travel_mode"] == "driving"


def test_route_preview_falls_back_to_osrm_when_google_traffic_fails(client) -> None:
    destination_a, destination_b, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(
        preview_result=OSRMRouteResult(
            total_distance_meters=12000,
            total_duration_seconds=1500,
            legs=[
                OSRMLeg(distance_meters=12000, duration_seconds=1500),
            ],
        ),
    )
    fake_google = FakeGoogleRoutesClient(
        error=GoogleRoutesClientError("daily limit reached"),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm
    client.app.dependency_overrides[get_google_routes_client] = lambda: fake_google

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={
            "destination_ids": [
                destination_a["destination_id"],
                destination_b["destination_id"],
            ],
            "travel_mode": "driving",
            "use_live_traffic": True,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "osrm"
    assert body["traffic"] is None
    assert "Live traffic was unavailable" in body["warnings"][0]
    assert fake_osrm.preview_calls[0]["travel_mode"] == "driving"


def test_route_optimize_uses_osrm_stop_order(client) -> None:
    destination_a, destination_b, destination_c = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(
        optimize_result=OSRMRouteResult(
            total_distance_meters=30000,
            total_duration_seconds=3600,
            legs=[
                OSRMLeg(distance_meters=10000, duration_seconds=1200),
                OSRMLeg(distance_meters=20000, duration_seconds=2400),
            ],
            stop_order=[0, 2, 1],
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/optimize",
        headers=user_headers(client),
        json={
            "destination_ids": [
                destination_a["destination_id"],
                destination_b["destination_id"],
                destination_c["destination_id"],
            ],
            "travel_mode": "driving",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "osrm"
    assert body["total_distance_km"] == "30.00"
    assert [stop["destination_id"] for stop in body["stops"]] == [
        destination_a["destination_id"],
        destination_c["destination_id"],
        destination_b["destination_id"],
    ]
    assert len(body["legs"]) == 2
    assert "suggested route order" in body["warnings"][0]
    assert fake_osrm.optimize_calls[0]["preserve_first"] is True


def test_route_preview_falls_back_to_haversine_when_osrm_fails(client) -> None:
    destination_a, destination_b, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(error=OSRMClientError("OSRM is down."))
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={
            "destination_ids": [
                destination_a["destination_id"],
                destination_b["destination_id"],
            ],
            "travel_mode": "walking",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "haversine"
    assert body["is_estimated"] is True
    assert body["total_distance_km"] != "0.00"
    assert body["legs"][0]["is_estimated"] is True
    assert "Haversine" in body["warnings"][0]


def test_public_transport_uses_estimated_route_without_osrm(client) -> None:
    destination_a, destination_b, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(error=AssertionError("OSRM should not be called."))
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={
            "destination_ids": [
                destination_a["destination_id"],
                destination_b["destination_id"],
            ],
            "travel_mode": "public_transport",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "stored_transportation_estimate"
    assert body["is_estimated"] is True
    assert fake_osrm.preview_calls == []
    assert fake_osrm.optimize_calls == []


def test_route_request_rejects_duplicate_destinations(client) -> None:
    destination_a, _, _ = create_route_destinations(client)

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={
            "destination_ids": [
                destination_a["destination_id"],
                destination_a["destination_id"],
            ],
            "travel_mode": "driving",
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_route_request_rejects_missing_destination(client) -> None:
    fake_osrm = FakeOSRMClient()
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={"destination_ids": [999], "travel_mode": "driving"},
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "destination_not_found"
    assert response.json()["error"]["details"]["destination_ids"] == [999]
    assert fake_osrm.preview_calls == []


def test_single_destination_route_returns_empty_legs(client) -> None:
    destination_a, _, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(error=AssertionError("OSRM should not be called."))
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={
            "destination_ids": [destination_a["destination_id"]],
            "travel_mode": "driving",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "none"
    assert body["total_distance_km"] == "0.00"
    assert body["total_duration_minutes"] == 0
    assert body["legs"] == []
    assert fake_osrm.preview_calls == []


def test_route_request_enforces_configured_destination_limit(client) -> None:
    fake_osrm = FakeOSRMClient()
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={"destination_ids": list(range(1, 12)), "travel_mode": "driving"},
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "route_destination_limit_exceeded"
    assert response.json()["error"]["details"]["max_destinations"] == 10
