import asyncio
from types import SimpleNamespace

import httpx

from app.integrations.google_routes.client import _parse_response as parse_google_response
from app.features.routes.schemas import RouteCoordinate
from app.integrations.osrm.client import OSRMClient, _parse_route_response as parse_osrm_response


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
    client = OSRMClient(settings=SimpleNamespace(osrm_profile_driving="driving"))
    captured = {}

    async def fake_get_json(path, *, params):
        captured.update(params)
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
