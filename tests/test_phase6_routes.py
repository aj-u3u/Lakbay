import pytest

from app.features.routes.schemas import RouteOptimizeRequest
from app.integrations.google_routes.client import get_google_routes_client
from app.integrations.google_routes.errors import GoogleRoutesClientError
from app.integrations.google_routes.schemas import GoogleRouteLeg, GoogleRouteResult
from app.integrations.osrm.client import get_osrm_client
from app.integrations.osrm.errors import OSRMClientError
from app.integrations.osrm.schemas import OSRMLeg, OSRMMatrixResult, OSRMRouteResult, OSRMStep


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
        matrix_result: OSRMMatrixResult | None = None,
        error: Exception | None = None,
    ) -> None:
        self.preview_result = preview_result
        self.optimize_result = optimize_result
        self.matrix_result = matrix_result
        self.error = error
        self.preview_calls = []
        self.optimize_calls = []
        self.matrix_calls = []

    async def matrix(self, **kwargs) -> OSRMMatrixResult:
        self.matrix_calls.append(kwargs)

        if self.error is not None:
            raise self.error
        if self.matrix_result is None:
            # Without a table, optimization uses OSRM Trip as before.
            raise OSRMClientError("This fake has no travel-time table.")

        return self.matrix_result

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
    assert body["arrival_points_verified"] is False
    assert body["stops"][0]["coordinate_basis"] == "attraction"
    assert body["legs"][0]["steps"] == []
    assert any("planning preview" in warning for warning in body["warnings"])


def test_route_preview_uses_verified_arrival_and_returns_directions(client) -> None:
    headers = admin_headers(client)
    verified = {
        "arrival_lat": 7.07,
        "arrival_lng": 125.61,
        "arrival_source_url": "https://example.com/arrival",
        "arrival_verified_at": "2026-10-29T00:00:00Z",
        "route_ready": True,
    }
    first = create_destination(client, headers, {**DESTINATION_A, **verified})
    second = create_destination(
        client, headers,
        {**DESTINATION_B, **verified, "arrival_lat": 7.10, "arrival_lng": 125.62},
    )
    fake_osrm = FakeOSRMClient(
        preview_result=OSRMRouteResult(
            total_distance_meters=1200,
            total_duration_seconds=300,
            polyline="encoded-route",
            legs=[OSRMLeg(
                distance_meters=1200,
                duration_seconds=300,
                steps=[OSRMStep(
                    distance_meters=1200,
                    duration_seconds=300,
                    maneuver_type="turn",
                    modifier="right",
                    road_name="Test Road",
                )],
            )],
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm
    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={"destination_ids": [first["destination_id"], second["destination_id"]]},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["arrival_points_verified"] is True
    assert body["stops"][0]["coordinate_basis"] == "verified_arrival"
    assert body["stops"][0]["lat"] == 7.07
    assert fake_osrm.preview_calls[0]["coordinates"][0].lat == 7.07
    assert body["polyline"] == "encoded-route"
    assert body["polyline_encoding"] == "polyline5"
    assert body["legs"][0]["steps"][0]["instruction"] == "Turn right onto Test Road"


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


def test_route_preview_falls_back_to_osrm_when_google_leg_count_mismatches(client) -> None:
    destination_a, destination_b, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(
        preview_result=OSRMRouteResult(
            total_distance_meters=12000,
            total_duration_seconds=1500,
            legs=[OSRMLeg(distance_meters=12000, duration_seconds=1500)],
        ),
    )
    fake_google = FakeGoogleRoutesClient(
        result=GoogleRouteResult(
            total_distance_meters=12000,
            total_duration_seconds=1500,
            total_static_duration_seconds=1500,
            legs=[],
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
    assert body["route_provider"] == "osrm"
    assert body["is_estimated"] is False
    assert body["total_distance_km"] == "12.00"
    assert body["traffic"] is None
    assert "Google Routes returned a leg count" in body["warnings"][0]
    assert len(fake_google.calls) == len(fake_osrm.preview_calls) == 1


@pytest.mark.parametrize(
    "preserve_first_destination,stop_order,expected_order",
    [
        (True, [0, 2, 1], [0, 2, 1]),
        (False, [1, 0, 2], [1, 0, 2]),
    ],
)
def test_route_optimize_uses_osrm_stop_order(
    client, preserve_first_destination: bool, stop_order: list[int],
    expected_order: list[int],
) -> None:
    destination_a, destination_b, destination_c = create_route_destinations(client)
    destination_ids = [
        destination_a["destination_id"],
        destination_b["destination_id"],
        destination_c["destination_id"],
    ]
    fake_osrm = FakeOSRMClient(
        optimize_result=OSRMRouteResult(
            total_distance_meters=30000,
            total_duration_seconds=3600,
            legs=[
                OSRMLeg(distance_meters=10000, duration_seconds=1200),
                OSRMLeg(distance_meters=20000, duration_seconds=2400),
            ],
            stop_order=stop_order,
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/optimize",
        headers=user_headers(client),
        json={
            "destination_ids": destination_ids,
            "travel_mode": "driving",
            "preserve_first_destination": preserve_first_destination,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "osrm"
    assert body["total_distance_km"] == "30.00"
    assert [stop["destination_id"] for stop in body["stops"]] == [
        destination_ids[index] for index in expected_order
    ]
    assert len(body["legs"]) == 2
    assert "suggested route order" in body["warnings"][0]
    assert fake_osrm.optimize_calls[0]["preserve_first"] is preserve_first_destination


@pytest.mark.parametrize("path", ["preview", "optimize"])
def test_route_rejects_return_to_origin_without_origin(client, path: str) -> None:
    fake_osrm = FakeOSRMClient(error=AssertionError("Invalid request must not call OSRM."))
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        f"/api/v1/routes/{path}",
        headers=user_headers(client),
        json={"destination_ids": [1], "return_to_origin": True},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
    assert fake_osrm.preview_calls == fake_osrm.optimize_calls == []


def test_route_preview_returns_to_supplied_origin(client) -> None:
    destination_a, _, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(
        preview_result=OSRMRouteResult(
            total_distance_meters=20000,
            total_duration_seconds=2400,
            legs=[
                OSRMLeg(distance_meters=10000, duration_seconds=1200),
                OSRMLeg(distance_meters=10000, duration_seconds=1200),
            ],
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={
            "destination_ids": [destination_a["destination_id"]],
            "origin": {"label": "Start", "lat": 7.0, "lng": 125.6},
            "return_to_origin": True,
        },
    )

    assert response.status_code == 200
    assert [stop["destination_id"] for stop in response.json()["stops"]] == [
        None, destination_a["destination_id"], None,
    ]


@pytest.mark.parametrize("preserve_first_destination", [True, False])
def test_route_optimize_keeps_origin_first_regardless_of_preserve_flag(
    client, preserve_first_destination: bool,
) -> None:
    destination_a, destination_b, _ = create_route_destinations(client)
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
            ],
            "origin": {"label": "Start", "lat": 7.0, "lng": 125.6},
            "preserve_first_destination": preserve_first_destination,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "osrm"
    assert [stop["destination_id"] for stop in body["stops"]] == [
        None,
        destination_b["destination_id"],
        destination_a["destination_id"],
    ]
    assert fake_osrm.optimize_calls[0]["preserve_first"] is True


def test_preserve_first_destination_description_explains_origin_precedence() -> None:
    description = RouteOptimizeRequest.model_fields["preserve_first_destination"].description

    assert "first listed destination" in description
    assert "origin is provided" in description
    assert "no effect" in description


def test_route_optimize_keeps_osrm_result_when_google_leg_count_mismatches(client) -> None:
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
    fake_google = FakeGoogleRoutesClient(
        result=GoogleRouteResult(
            total_distance_meters=30000,
            total_duration_seconds=3600,
            total_static_duration_seconds=3600,
            legs=[],
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm
    client.app.dependency_overrides[get_google_routes_client] = lambda: fake_google

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
            "use_live_traffic": True,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "osrm"
    assert body["is_estimated"] is False
    assert body["total_distance_km"] == "30.00"
    assert [stop["destination_id"] for stop in body["stops"]] == [
        destination_a["destination_id"],
        destination_c["destination_id"],
        destination_b["destination_id"],
    ]
    assert any("Google Routes returned a leg count" in warning for warning in body["warnings"])
    assert any("not guaranteed to be mathematically optimal" in warning for warning in body["warnings"])
    assert len(fake_google.calls) == len(fake_osrm.optimize_calls) == 1


def test_one_destination_from_origin_uses_fixed_order_road_route(client) -> None:
    destination_a, _, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(
        preview_result=OSRMRouteResult(
            total_distance_meters=12000,
            total_duration_seconds=1500,
            legs=[OSRMLeg(distance_meters=12000, duration_seconds=1500)],
            polyline="encoded-road-route",
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/optimize",
        headers=user_headers(client),
        json={
            "destination_ids": [destination_a["destination_id"]],
            "travel_mode": "driving",
            "origin": {"label": "Your Location", "lat": 7.03, "lng": 125.61},
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "osrm"
    assert body["is_estimated"] is False
    assert body["total_distance_km"] == "12.00"
    assert body["total_duration_minutes"] == 25
    assert body["polyline"] == "encoded-road-route"
    assert body["stops"][0]["is_origin"] is True
    assert body["stops"][1]["destination_id"] == destination_a["destination_id"]
    assert body["arrival_points_verified"] is False
    assert body["legs"][0]["steps"] == []
    assert fake_osrm.optimize_calls == []
    assert len(fake_osrm.preview_calls) == 1
    assert not any("suggested route order" in warning for warning in body["warnings"])


def test_one_destination_from_origin_keeps_labeled_estimate_on_road_failure(client) -> None:
    destination_a, _, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(error=OSRMClientError("OSRM is down."))
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/optimize",
        headers=user_headers(client),
        json={
            "destination_ids": [destination_a["destination_id"]],
            "travel_mode": "driving",
            "origin": {"label": "Your Location", "lat": 7.03, "lng": 125.61},
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["route_provider"] == "haversine"
    assert body["is_estimated"] is True
    assert body["polyline"] is None
    assert body["legs"][0]["steps"] == []
    assert any("OSRM was unavailable" in warning for warning in body["warnings"])
    assert fake_osrm.optimize_calls == []
    assert len(fake_osrm.preview_calls) == 1


def test_route_optimize_estimates_when_osrm_fails_and_google_leg_count_mismatches(client) -> None:
    destination_a, destination_b, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(error=OSRMClientError("OSRM is down."))
    fake_google = FakeGoogleRoutesClient(
        result=GoogleRouteResult(
            total_distance_meters=12000,
            total_duration_seconds=1500,
            total_static_duration_seconds=1500,
            legs=[],
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm
    client.app.dependency_overrides[get_google_routes_client] = lambda: fake_google

    response = client.post(
        "/api/v1/routes/optimize",
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
    assert body["route_provider"] == "haversine"
    assert body["is_estimated"] is True
    assert any("Google Routes returned a leg count" in warning for warning in body["warnings"])
    assert any("OSRM optimization was unavailable" in warning for warning in body["warnings"])
    assert len(fake_google.calls) == len(fake_osrm.optimize_calls) == 1


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


# Travel seconds between stops A, B and C (row = from, column = to). Visiting
# C, then A, then B is the quickest order at 200 seconds in total.
EXACT_ORDER_MATRIX = OSRMMatrixResult(
    durations_seconds=[
        [0, 100, 1000],
        [1000, 0, 1000],
        [100, 1000, 0],
    ],
    distances_meters=[
        [0, 1000, 10000],
        [10000, 0, 10000],
        [1000, 10000, 0],
    ],
)
TWO_LEG_ROUTE = OSRMRouteResult(
    total_distance_meters=2000,
    total_duration_seconds=200,
    legs=[
        OSRMLeg(distance_meters=1000, duration_seconds=100),
        OSRMLeg(distance_meters=1000, duration_seconds=100),
    ],
)


@pytest.mark.parametrize(
    "preserve_first_destination,expected_order",
    [
        (False, [2, 0, 1]),
        (True, [0, 1, 2]),
    ],
)
def test_route_optimize_picks_the_exact_shortest_order(
    client, preserve_first_destination: bool, expected_order: list[int],
) -> None:
    destinations = create_route_destinations(client)
    destination_ids = [destination["destination_id"] for destination in destinations]
    fake_osrm = FakeOSRMClient(
        matrix_result=EXACT_ORDER_MATRIX,
        preview_result=TWO_LEG_ROUTE,
        error=None,
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/optimize",
        headers=user_headers(client),
        json={
            "destination_ids": destination_ids,
            "travel_mode": "driving",
            "preserve_first_destination": preserve_first_destination,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["order_method"] == "exact"
    assert body["route_provider"] == "osrm"
    assert body["is_estimated"] is False
    assert [stop["destination_id"] for stop in body["stops"]] == [
        destination_ids[index] for index in expected_order
    ]
    assert any("shortest total travel time" in warning for warning in body["warnings"])
    assert len(fake_osrm.matrix_calls) == 1
    assert fake_osrm.optimize_calls == []
    assert [
        (coordinate.lat, coordinate.lng)
        for coordinate in fake_osrm.preview_calls[0]["coordinates"]
    ] == [(destinations[index]["lat"], destinations[index]["lng"]) for index in expected_order]


def test_route_optimize_uses_osrm_trip_when_a_stop_pair_has_no_road(client) -> None:
    destination_a, destination_b, destination_c = create_route_destinations(client)
    durations = [list(row) for row in EXACT_ORDER_MATRIX.durations_seconds]
    durations[0][2] = None
    fake_osrm = FakeOSRMClient(
        matrix_result=OSRMMatrixResult(
            durations_seconds=durations,
            distances_meters=EXACT_ORDER_MATRIX.distances_meters,
        ),
        optimize_result=OSRMRouteResult(
            total_distance_meters=2000,
            total_duration_seconds=200,
            legs=TWO_LEG_ROUTE.legs,
            stop_order=[0, 1, 2],
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
    assert body["order_method"] == "osrm_trip"
    assert len(fake_osrm.matrix_calls) == 1
    assert len(fake_osrm.optimize_calls) == 1
    assert fake_osrm.preview_calls == []


def test_route_optimize_labels_osrm_trip_when_the_table_is_unavailable(client) -> None:
    destination_a, destination_b, destination_c = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(optimize_result=OSRMRouteResult(
        total_distance_meters=2000,
        total_duration_seconds=200,
        legs=TWO_LEG_ROUTE.legs,
        stop_order=[0, 2, 1],
    ))
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
    assert response.json()["order_method"] == "osrm_trip"


def test_route_optimize_labels_the_haversine_fallback_when_osrm_is_down(client) -> None:
    destination_a, destination_b, destination_c = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(error=OSRMClientError("OSRM is down."))
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
    assert body["order_method"] == "nearest_neighbor_2opt"
    assert body["route_provider"] == "haversine"
    assert any("2-opt" in warning for warning in body["warnings"])


def test_public_transport_optimize_and_preview_report_their_order_method(client) -> None:
    destination_a, destination_b, _ = create_route_destinations(client)
    fake_osrm = FakeOSRMClient(
        preview_result=OSRMRouteResult(
            total_distance_meters=1000,
            total_duration_seconds=100,
            legs=[OSRMLeg(distance_meters=1000, duration_seconds=100)],
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm
    headers = user_headers(client)
    destination_ids = [destination_a["destination_id"], destination_b["destination_id"]]

    transit = client.post(
        "/api/v1/routes/optimize",
        headers=headers,
        json={"destination_ids": destination_ids, "travel_mode": "public_transport"},
    )
    preview = client.post(
        "/api/v1/routes/preview",
        headers=headers,
        json={"destination_ids": destination_ids, "travel_mode": "driving"},
    )

    assert transit.json()["order_method"] == "nearest_neighbor_2opt"
    assert preview.json()["order_method"] == "requested"
