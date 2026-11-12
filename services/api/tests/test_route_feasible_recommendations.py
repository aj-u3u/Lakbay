"""OSRM checks that decide whether a recommended place has a confirmed road route.

The ranking itself is tested in `test_top_places_scoring.py`.
"""

import pytest

from app.integrations.osrm.client import _require_near_route_waypoints
from app.integrations.osrm.errors import OSRMRouteNotFoundError


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
