import asyncio

from app.core.config import Settings
from app.features.routes.schemas import RouteCoordinate
from app.features.routes.service import _osrm_instruction
from app.integrations.osrm import client as osrm_module
from app.integrations.osrm.client import (
    OSRMClient,
    _parse_route_response,
    get_osrm_client,
)
from app.integrations.osrm.schemas import (
    OSRMFerryCrossing,
    OSRMLeg,
    OSRMRouteResult,
    OSRMStep,
)
from tests.test_phase6_routes import (
    DESTINATION_A,
    DESTINATION_B,
    FakeOSRMClient,
    admin_headers,
    create_destination,
    user_headers,
)

# A shortened Davao City to Samal response: drive, ferry, drive, arrive.
SAMAL_ROUTE = {
    "code": "Ok",
    "waypoints": [{"distance": 3.0}, {"distance": 12.0}],
    "routes": [
        {
            "distance": 19500.0,
            "duration": 3240.0,
            "geometry": "encoded",
            "legs": [
                {
                    "distance": 19500.0,
                    "duration": 3240.0,
                    "steps": [
                        {
                            "distance": 9000.0,
                            "duration": 1200.0,
                            "name": "R.T. Lim Boulevard",
                            "mode": "driving",
                            "maneuver": {"type": "depart", "location": [125.6092, 7.0706]},
                        },
                        {
                            "distance": 1600.0,
                            "duration": 1200.0,
                            "name": "Sasa - Kinawitnon",
                            "mode": "ferry",
                            "maneuver": {"type": "notification", "location": [125.6401, 7.1105]},
                        },
                        {
                            "distance": 8900.0,
                            "duration": 840.0,
                            "name": "Circumferential Road",
                            "mode": "driving",
                            "maneuver": {"type": "turn", "modifier": "right", "location": [125.6512, 7.1062]},
                        },
                        {
                            "distance": 0.0,
                            "duration": 0.0,
                            "name": "",
                            "mode": "driving",
                            "maneuver": {"type": "arrive", "location": [125.7087, 7.0744]},
                        },
                    ],
                }
            ],
        }
    ],
}


def test_parser_finds_the_ferry_and_its_piers() -> None:
    result = _parse_route_response(SAMAL_ROUTE)

    assert result.legs[0].steps[1].mode == "ferry"
    assert result.legs[0].steps[0].location == (7.0706, 125.6092)
    assert result.ferry_crossings == [
        OSRMFerryCrossing(
            distance_meters=1600.0,
            duration_seconds=1200.0,
            name="Sasa - Kinawitnon",
            start=(7.1105, 125.6401),
            end=(7.1062, 125.6512),
        )
    ]


def test_road_only_route_has_no_ferry() -> None:
    body = {
        **SAMAL_ROUTE,
        "routes": [
            {
                **SAMAL_ROUTE["routes"][0],
                "legs": [
                    {
                        **SAMAL_ROUTE["routes"][0]["legs"][0],
                        "steps": [SAMAL_ROUTE["routes"][0]["legs"][0]["steps"][0]],
                    }
                ],
            }
        ],
    }

    assert _parse_route_response(body).ferry_crossings == []


def test_client_requests_the_full_road_line(monkeypatch) -> None:
    calls: list[tuple[str, dict]] = []

    async def fake_get_json(self, path, *, params, base_url):
        calls.append((path, params))
        if path.startswith("/trip/"):
            return {
                "code": "Ok",
                "waypoints": [
                    {"waypoint_index": 0, "trips_index": 0},
                    {"waypoint_index": 1, "trips_index": 0},
                ],
                "trips": [SAMAL_ROUTE["routes"][0]],
            }
        return SAMAL_ROUTE

    monkeypatch.setattr(osrm_module.OSRMClient, "_get_json", fake_get_json)
    client = OSRMClient(Settings(osrm_base_url="http://osrm.test"))
    coordinates = [
        RouteCoordinate(lat=7.0706, lng=125.6092),
        RouteCoordinate(lat=7.0744, lng=125.7087),
    ]

    asyncio.run(client.preview_route(travel_mode="driving", coordinates=coordinates))
    optimized = asyncio.run(
        client.optimize_route(
            travel_mode="driving",
            coordinates=coordinates,
            roundtrip=False,
            preserve_first=True,
        )
    )

    assert [params["overview"] for _, params in calls] == ["full", "full"]
    assert optimized.ferry_crossings[0].name == "Sasa - Kinawitnon"


def test_route_response_reports_the_ferry(client) -> None:
    headers = admin_headers(client)
    first = create_destination(client, headers, DESTINATION_A)
    second = create_destination(client, headers, DESTINATION_B)
    fake_osrm = FakeOSRMClient(
        preview_result=OSRMRouteResult(
            total_distance_meters=19500,
            total_duration_seconds=3240,
            legs=[
                OSRMLeg(
                    distance_meters=19500,
                    duration_seconds=3240,
                    steps=[
                        OSRMStep(
                            distance_meters=1600,
                            duration_seconds=1200,
                            maneuver_type="notification",
                            road_name="Sasa - Kinawitnon",
                            mode="ferry",
                        )
                    ],
                )
            ],
            ferry_crossings=[
                OSRMFerryCrossing(
                    distance_meters=1600,
                    duration_seconds=1200,
                    name="Sasa - Kinawitnon",
                    start=(7.1105, 125.6401),
                    end=(7.1062, 125.6512),
                )
            ],
        ),
    )
    client.app.dependency_overrides[get_osrm_client] = lambda: fake_osrm

    response = client.post(
        "/api/v1/routes/preview",
        headers=user_headers(client),
        json={
            "destination_ids": [first["destination_id"], second["destination_id"]],
            "travel_mode": "driving",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["ferry_crossings"] == [
        {
            "name": "Sasa - Kinawitnon",
            "distance_km": "1.60",
            "duration_minutes": 20,
            "from_lat": 7.1105,
            "from_lng": 125.6401,
            "to_lat": 7.1062,
            "to_lng": 125.6512,
        }
    ]
    assert any(
        "ferry crossing (Sasa - Kinawitnon)" in warning and "20 min" in warning
        for warning in body["warnings"]
    )


def test_ferry_step_instruction() -> None:
    step = OSRMStep(
        distance_meters=1600,
        duration_seconds=1200,
        maneuver_type="notification",
        road_name="Sasa - Kinawitnon",
        mode="ferry",
    )

    assert _osrm_instruction(step) == "Take the ferry (Sasa - Kinawitnon)"
