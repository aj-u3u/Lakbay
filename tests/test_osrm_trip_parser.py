import json
from pathlib import Path

import pytest

from app.features.routes.service import RoutePlanStop, _apply_stop_order
from app.integrations.osrm.client import _parse_trip_response
from app.integrations.osrm.errors import OSRMClientError


SAMPLE_PATH = Path(__file__).parent / "fixtures" / "trip_sample.json"


def sample_trip() -> dict:
    return json.loads(SAMPLE_PATH.read_text(encoding="utf-8"))


def test_real_trip_sample_parses() -> None:
    body = sample_trip()

    result = _parse_trip_response(body, expected_count=3)

    assert result.stop_order == [0, 1, 2]
    assert result.total_distance_meters == 7210.7
    assert len(result.legs) == 2
    assert result.polyline == body["trips"][0]["geometry"]


def test_shuffled_waypoint_indices_are_accepted() -> None:
    body = sample_trip()
    for waypoint, waypoint_index in zip(body["waypoints"], [2, 0, 1]):
        waypoint["waypoint_index"] = waypoint_index

    result = _parse_trip_response(body, expected_count=3)

    assert result.stop_order == [1, 2, 0]


@pytest.mark.parametrize("trip_count", [0, 2])
def test_trip_parser_rejects_non_single_trip_count(trip_count: int) -> None:
    body = sample_trip()
    body["trips"] = body["trips"] * trip_count

    with pytest.raises(OSRMClientError):
        _parse_trip_response(body, expected_count=3)


@pytest.mark.parametrize("waypoint_count", [2, 4])
def test_trip_parser_rejects_waypoint_count_mismatch(waypoint_count: int) -> None:
    body = sample_trip()
    body["waypoints"] = (body["waypoints"] * 2)[:waypoint_count]

    with pytest.raises(OSRMClientError):
        _parse_trip_response(body, expected_count=3)


@pytest.mark.parametrize("field", ["waypoint_index", "trips_index"])
def test_trip_parser_rejects_missing_waypoint_index_fields(field: str) -> None:
    body = sample_trip()
    del body["waypoints"][0][field]

    with pytest.raises(OSRMClientError):
        _parse_trip_response(body, expected_count=3)


@pytest.mark.parametrize("field", ["waypoint_index", "trips_index"])
@pytest.mark.parametrize("value", [None, "0", 0.0, True, False])
def test_trip_parser_rejects_non_integer_waypoint_index_fields(field: str, value) -> None:
    body = sample_trip()
    body["waypoints"][0][field] = value

    with pytest.raises(OSRMClientError):
        _parse_trip_response(body, expected_count=3)


def test_trip_parser_rejects_waypoint_assigned_to_another_trip() -> None:
    body = sample_trip()
    body["waypoints"][0]["trips_index"] = 1

    with pytest.raises(OSRMClientError):
        _parse_trip_response(body, expected_count=3)


@pytest.mark.parametrize("waypoint_indices", [[0, 0, 2], [0, 1, 3], [-1, 1, 2]])
def test_trip_parser_rejects_invalid_waypoint_index_set(waypoint_indices: list[int]) -> None:
    body = sample_trip()
    for waypoint, waypoint_index in zip(body["waypoints"], waypoint_indices):
        waypoint["waypoint_index"] = waypoint_index

    with pytest.raises(OSRMClientError):
        _parse_trip_response(body, expected_count=3)


def test_apply_stop_order_rejects_moved_first_stop_when_preserved() -> None:
    stops = [RoutePlanStop(index, str(index), 7.0, 125.0) for index in range(3)]

    with pytest.raises(ValueError, match="preserved first stop"):
        _apply_stop_order(stops, [1, 0, 2], preserve_first=True)


def test_apply_stop_order_accepts_moved_first_stop_when_not_preserved() -> None:
    stops = [RoutePlanStop(index, str(index), 7.0, 125.0) for index in range(3)]

    assert _apply_stop_order(stops, [1, 0, 2], preserve_first=False) == [
        stops[1], stops[0], stops[2],
    ]
