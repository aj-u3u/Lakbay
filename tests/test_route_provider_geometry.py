import asyncio
from types import SimpleNamespace

import httpx

from app.integrations.google_routes.client import _parse_response as parse_google_response
from app.features.routes.schemas import RouteCoordinate
from app.integrations.osrm.client import OSRMClient, _parse_route_response as parse_osrm_response
from app.integrations.osrm.errors import OSRMConfigurationError
import pytest


def test_osrm_parser_keeps_polyline_and_maneuvers() -> None:
    result = parse_osrm_response({
        "routes": [{
            "distance": 1500,
            "duration": 360,
            "geometry": "encoded-osrm",
            "legs": [{
                "distance": 1500,
                "duration": 360,
                "steps": [{
                    "distance": 400,
                    "duration": 90,
                    "name": "Main Street",
                    "maneuver": {"type": "turn", "modifier": "left"},
                }],
            }],
        }],
    })
    assert result.polyline == "encoded-osrm"
    assert result.legs[0].steps[0].road_name == "Main Street"
    assert result.legs[0].steps[0].modifier == "left"


def test_google_parser_keeps_polyline_and_navigation_steps() -> None:
    response = httpx.Response(200, json={
        "routes": [{
            "distanceMeters": 1500,
            "duration": "360s",
            "staticDuration": "300s",
            "polyline": {"encodedPolyline": "encoded-google"},
            "legs": [{
                "distanceMeters": 1500,
                "duration": "360s",
                "staticDuration": "300s",
                "steps": [{
                    "distanceMeters": 400,
                    "staticDuration": "90s",
                    "navigationInstruction": {"instructions": "Turn left"},
                }],
            }],
        }],
    })
    result = parse_google_response(response)
    assert result.polyline == "encoded-google"
    assert result.legs[0].steps[0].instruction == "Turn left"
    assert result.legs[0].steps[0].duration_seconds == 90


def test_open_osrm_trip_uses_supported_fixed_endpoints() -> None:
    client = OSRMClient(settings=SimpleNamespace(
        osrm_profile_driving="driving", osrm_base_url="https://car.example.test"
    ))
    captured = {}

    async def fake_get_json(path, *, params, base_url):
        captured.update(params)
        captured["base_url"] = base_url
        return {"trips": [{"distance": 0, "duration": 0, "legs": []}],
                "waypoints": [{"waypoint_index": 0, "trips_index": 0},
                              {"waypoint_index": 1, "trips_index": 0}]}

    client._get_json = fake_get_json
    asyncio.run(client.optimize_route(
        travel_mode="driving",
        coordinates=[RouteCoordinate(lat=7.0, lng=125.0),
                     RouteCoordinate(lat=7.1, lng=125.1)],
        roundtrip=False,
        preserve_first=False,
    ))
    assert captured["source"] == "first"
    assert captured["destination"] == "last"
    assert captured["steps"] == "true"
    assert captured["base_url"] == "https://car.example.test"


def test_walking_requires_separate_osrm_service() -> None:
    client = OSRMClient(settings=SimpleNamespace(
        osrm_profile_walking="walking",
        osrm_base_url="https://car.example.test",
        osrm_walking_base_url=None,
    ))

    with pytest.raises(OSRMConfigurationError, match="OSRM_WALKING_BASE_URL"):
        asyncio.run(client.preview_route(
            travel_mode="walking",
            coordinates=[RouteCoordinate(lat=7.0, lng=125.0),
                         RouteCoordinate(lat=7.1, lng=125.1)],
        ))


def test_walking_uses_its_configured_service() -> None:
    client = OSRMClient(settings=SimpleNamespace(
        osrm_profile_walking="walking",
        osrm_base_url="https://car.example.test",
        osrm_walking_base_url="https://foot.example.test",
    ))
    captured = {}

    async def fake_get_json(path, *, params, base_url):
        captured["base_url"] = base_url
        return {"routes": [{"distance": 100, "duration": 80, "legs": [{"distance": 100, "duration": 80}]}],
                "waypoints": [{"distance": 0}, {"distance": 0}]}

    client._get_json = fake_get_json
    asyncio.run(client.preview_route(
        travel_mode="walking",
        coordinates=[RouteCoordinate(lat=7.0, lng=125.0),
                     RouteCoordinate(lat=7.1, lng=125.1)],
    ))
    assert captured["base_url"] == "https://foot.example.test"


def test_walking_rejects_driving_service_url() -> None:
    client = OSRMClient(settings=SimpleNamespace(
        osrm_profile_walking="walking",
        osrm_base_url="https://car.example.test/",
        osrm_walking_base_url="https://car.example.test",
    ))

    with pytest.raises(OSRMConfigurationError, match="separate foot-profile"):
        asyncio.run(client.preview_route(
            travel_mode="walking",
            coordinates=[RouteCoordinate(lat=7.0, lng=125.0),
                         RouteCoordinate(lat=7.1, lng=125.1)],
        ))
