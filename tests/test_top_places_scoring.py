"""Personalized Top 5: the weighted scoring model and POST /recommendations/top-places."""

from decimal import Decimal

import pytest

from app.core.config import get_settings
from app.features.destinations.candidate_repository import distance_meters
from app.features.recommendations import scoring
from app.integrations.osrm.client import _parse_table_response, get_osrm_client
from app.integrations.osrm.errors import OSRMClientError
from app.integrations.osrm.schemas import OSRMTableEntry, OSRMTableResult
from tests.test_phase2_destination_data import admin_headers, user_headers
from tests.test_phase5_ai_itineraries import create_destination


PATH = "/api/v1/recommendations/top-places"
NEAR_A = {"label": "Near A", "lat": 7.101, "lng": 125.6}
NEAR_B = {"label": "Near B", "lat": 7.399, "lng": 125.7}


class TableOSRM:
    """Fake OSRM table: 40 km/h along the straight line unless a lat is overridden."""

    def __init__(self, *, minutes_by_lat: dict[float, int | None] | None = None, fail: bool = False):
        self.minutes_by_lat = minutes_by_lat or {}
        self.fail = fail
        self.calls = 0

    async def table(self, *, travel_mode, origin, destinations):
        self.calls += 1
        if self.fail:
            raise OSRMClientError("OSRM request failed.")
        entries = []
        for point in destinations:
            meters = distance_meters(origin.lat, origin.lng, point.lat, point.lng)
            minutes = self.minutes_by_lat.get(round(point.lat, 4), meters / 1000 / 40 * 60)
            entries.append(
                OSRMTableEntry(duration_seconds=None, distance_meters=None, snap_meters=5.0)
                if minutes is None
                else OSRMTableEntry(duration_seconds=minutes * 60, distance_meters=meters, snap_meters=5.0)
            )
        return OSRMTableResult(source_snap_meters=5.0, entries=entries)


def place(client, headers, name: str, **overrides) -> dict:
    return create_destination(client, headers=headers, name=name, **overrides)


def verified_arrival(lat: float, lng: float) -> dict:
    return {
        "lat": lat, "lng": lng, "arrival_lat": lat, "arrival_lng": lng,
        "arrival_source_url": "https://example.org/visitor-gate",
        "arrival_verified_at": "2026-10-29T00:00:00Z", "route_ready": True,
    }


@pytest.fixture
def osrm(client):
    fake = TableOSRM()
    client.app.dependency_overrides[get_osrm_client] = lambda: fake
    return fake


# Scoring functions -------------------------------------------------------


def test_weights_add_up_to_one() -> None:
    assert sum(scoring.WEIGHTS.values()) == pytest.approx(1.0)


def test_normalization_edges() -> None:
    assert scoring.travel_score(0, 180) == 1
    assert scoring.travel_score(90, 180) == 0.5
    assert scoring.travel_score(180, 180) == 0
    assert scoring.travel_score(240, 180) == 0
    assert scoring.travel_score(None, 180) == scoring.NEUTRAL
    assert scoring.budget_score(Decimal("500"), Decimal("1000")) == 1
    assert scoring.budget_score(Decimal("750"), Decimal("1000")) == pytest.approx(0.5)
    assert scoring.budget_score(Decimal("1000"), Decimal("1000")) == 0
    assert scoring.budget_score(None, Decimal("1000")) == scoring.NEUTRAL
    assert scoring.budget_score(Decimal("500"), None) == scoring.NEUTRAL
    assert scoring.interest_score(0, 0) == scoring.NEUTRAL
    assert scoring.interest_score(2, 1) == 0.5
    assert scoring.group_fit_score(has_children=False, traveler_count=2, is_kid_friendly=False, group_friendly=False) == 1
    assert scoring.group_fit_score(has_children=True, traveler_count=3, is_kid_friendly=False, group_friendly=True) == 0
    assert scoring.group_fit_score(has_children=True, traveler_count=6, is_kid_friendly=True, group_friendly=False) == 0.5
    assert scoring.popularity_score(None) == 0
    assert scoring.popularity_score(Decimal("90")) == pytest.approx(0.9)
    assert scoring.popularity_score(Decimal("250")) == 1
    assert scoring.max_travel_minutes(None) == 180
    assert scoring.max_travel_minutes(1) == 180
    assert scoring.max_travel_minutes(3) == 300


def test_interest_matches_report_values_and_fields() -> None:
    matched, fields = scoring.interest_matches(
        ["Nature", "family", "diving"],
        {"category": "nature park", "vibes": "family, relaxed", "activities": None},
    )
    assert matched == ["Nature", "family"]
    assert fields == ["category", "vibes"]


@pytest.mark.parametrize(("values", "expected"), [
    # Worked example in docs/recommendations.md (places A, B, C).
    ({"interest": 1.0, "travel": 1 - 55 / 180, "budget": scoring.budget_score(Decimal("385"), Decimal("1000")),
      "group_fit": 1.0, "popularity": 0.9}, 91),
    ({"interest": 0.5, "travel": 1 - 25 / 180, "budget": scoring.budget_score(Decimal("200"), Decimal("1000")),
      "group_fit": 1.0, "popularity": 0.6}, 75),
    ({"interest": 1.0, "travel": 1 - 150 / 180, "budget": scoring.budget_score(Decimal("800"), Decimal("1000")),
      "group_fit": 1.0, "popularity": 1.0}, 67),
])
def test_worked_example(values, expected) -> None:
    points = scoring.weighted_points(values)
    score = scoring.total_score(points)
    assert round(score) == expected
    assert score == pytest.approx(sum(points.values()))


# Endpoint ----------------------------------------------------------------


def test_top_places_requires_sign_in(client) -> None:
    assert client.post(PATH, json={}).status_code == 401


def test_start_point_changes_the_ranking(client, osrm) -> None:
    admin = admin_headers(client)
    a = place(client, admin, "Place A", lat=7.1, lng=125.6)
    b = place(client, admin, "Place B", lat=7.4, lng=125.7)
    traveler = user_headers(client)

    near_a = client.post(PATH, headers=traveler, json={"interests": ["beach"], "origin": NEAR_A})
    near_b = client.post(PATH, headers=traveler, json={"interests": ["beach"], "origin": NEAR_B})

    assert near_a.status_code == 201
    assert [item["destination_id"] for item in near_a.json()["items"]] == [a["destination_id"], b["destination_id"]]
    assert [item["destination_id"] for item in near_b.json()["items"]] == [b["destination_id"], a["destination_id"]]
    first = near_a.json()["items"][0]
    assert first["travel_basis"] == "approximate_location"
    assert first["route_verified"] is False
    assert first["route_provider"] == "osrm"
    assert osrm.calls == 2


def test_children_and_budget_change_the_ranking(client, osrm) -> None:
    admin = admin_headers(client)
    cheap = place(client, admin, "Cheap Beach", estimated_cost="200.00", is_kid_friendly=False)
    family = place(client, admin, "Family Beach", estimated_cost="700.00", is_kid_friendly=True)
    traveler = user_headers(client)
    body = {"interests": ["beach"], "total_budget": "3000.00", "budget_scope": "whole_trip"}

    adults = client.post(PATH, headers=traveler, json={**body, "adult_count": 3})
    with_child = client.post(PATH, headers=traveler, json={**body, "adult_count": 2, "child_ages": [7]})
    tight = client.post(PATH, headers=traveler, json={**body, "total_budget": "1500.00", "adult_count": 3})

    assert [item["destination_id"] for item in adults.json()["items"]] == [cheap["destination_id"], family["destination_id"]]
    assert [item["destination_id"] for item in with_child.json()["items"]] == [family["destination_id"], cheap["destination_id"]]
    assert "Kid-friendly." in with_child.json()["items"][0]["reasons"]
    assert [item["destination_id"] for item in tight.json()["items"]] == [cheap["destination_id"]]
    assert tight.json()["skipped"]["over_budget"] == 1


def test_score_equals_breakdown_and_reports_method(client, osrm) -> None:
    admin = admin_headers(client)
    place(client, admin, "Beach One")
    place(client, admin, "Beach Two", lat=6.96)
    response = client.post(
        PATH, headers=user_headers(client),
        json={"interests": ["beach", "hiking"], "origin": NEAR_A, "total_budget": "4000.00", "adult_count": 2},
    )

    body = response.json()
    assert body["method"] == "simple_additive_weighting"
    assert body["weights"] == scoring.WEIGHTS
    assert body["max_travel_minutes"] == 180
    assert [item["rank"] for item in body["items"]] == [1, 2]
    for item in body["items"]:
        points = [factor["points"] for factor in item["breakdown"].values()]
        assert item["score"] == pytest.approx(sum(points))
        assert 0 <= item["score"] <= 100
        assert item["breakdown"]["interest"]["value"] == 0.5
        assert item["matched_interests"] == ["beach"]
        assert item["cost_basis"] == "catalog_estimate"


def test_filters_are_counted_and_explained(client, osrm) -> None:
    admin = admin_headers(client)
    keep = place(client, admin, "Beach Keep", lat=7.11)
    place(client, admin, "Mountain", category="mountain", vibes="adventure", activities="hiking")
    place(client, admin, "Beach Ferry", how_to_get_there="Take the ferry from Sasa.")
    place(client, admin, "Beach Far", lat=7.2)
    place(client, admin, "Beach No Road", lat=7.3)
    place(client, admin, "Beach Elsewhere", district="Davao del Norte")
    osrm.minutes_by_lat = {7.2: 400, 7.3: None}

    response = client.post(
        PATH, headers=user_headers(client),
        json={"interests": ["beach"], "origin": NEAR_A, "preferred_districts": ["Davao Oriental"]},
    )

    body = response.json()
    assert [item["destination_id"] for item in body["items"]] == [keep["destination_id"]]
    assert body["skipped"] == {
        "no_interest_match": 1, "outside_preferred_districts": 1,
        "missing_required_accessibility": 0, "over_budget": 0,
        "needs_boat_or_ferry": 1, "no_route": 1, "too_far": 1,
    }
    assert body["shortfall_reason"] == (
        "Only 1 place qualifies for your Top 5: 1 does not match your interests, "
        "1 is outside your chosen districts, 1 needs a boat or ferry, "
        "1 has no road route from your start and 1 is too far for your trip length."
    )


def test_required_accessibility_and_no_interest_match(client, osrm) -> None:
    admin = admin_headers(client)
    place(client, admin, "Beach Steps", is_wheelchair_accessible=False)
    traveler = user_headers(client)

    needs_ramp = client.post(PATH, headers=traveler, json={"interests": ["beach"], "requires_wheelchair_accessible": True})
    no_match = client.post(PATH, headers=traveler, json={"interests": ["museum"]})

    assert needs_ramp.json()["items"] == []
    assert needs_ramp.json()["skipped"]["missing_required_accessibility"] == 1
    assert no_match.json()["items"] == []
    assert no_match.json()["shortfall_reason"] == "No active catalog destination matches the supplied travel interests."


def test_unknown_cost_is_kept_with_a_neutral_budget_score(client, osrm) -> None:
    place(client, admin_headers(client), "Beach Mystery Fee", estimated_cost=None)
    response = client.post(
        PATH, headers=user_headers(client),
        json={"interests": ["beach"], "total_budget": "500.00", "adult_count": 1},
    )

    [item] = response.json()["items"]
    assert item["cost_basis"] == "not_listed"
    assert item["breakdown"]["budget"]["value"] == scoring.NEUTRAL
    assert "Cost not listed." in item["reasons"]


def test_verified_routes_come_first_even_with_a_lower_score(client, osrm) -> None:
    admin = admin_headers(client)
    verified = place(client, admin, "Beach Verified", **verified_arrival(7.3, 125.6))
    near = place(client, admin, "Beach Near Pin", lat=7.105, lng=125.6)
    response = client.post(PATH, headers=user_headers(client), json={"interests": ["beach"], "origin": NEAR_A})

    items = response.json()["items"]
    assert [item["destination_id"] for item in items] == [verified["destination_id"], near["destination_id"]]
    assert items[0]["score"] < items[1]["score"]
    assert items[0]["travel_basis"] == "road_route"
    assert items[0]["route_verified"] is True
    assert response.json()["verified_count"] == 1
    assert any("approximate" in warning for warning in response.json()["warnings"])


def test_far_snap_to_road_is_not_verified(client) -> None:
    place(client, admin_headers(client), "Beach Verified", **verified_arrival(7.3, 125.6))

    class FarSnap(TableOSRM):
        async def table(self, **kwargs):
            result = await super().table(**kwargs)
            return OSRMTableResult(
                source_snap_meters=5.0,
                entries=[OSRMTableEntry(entry.duration_seconds, entry.distance_meters, 900.0) for entry in result.entries],
            )

    client.app.dependency_overrides[get_osrm_client] = lambda: FarSnap()
    response = client.post(PATH, headers=user_headers(client), json={"interests": ["beach"], "origin": NEAR_A})

    [item] = response.json()["items"]
    assert item["route_verified"] is False
    assert item["travel_basis"] == "approximate_location"


def test_routing_failure_falls_back_to_straight_line(client) -> None:
    place(client, admin_headers(client), "Beach One")
    client.app.dependency_overrides[get_osrm_client] = lambda: TableOSRM(fail=True)
    response = client.post(PATH, headers=user_headers(client), json={"interests": ["beach"], "origin": NEAR_A})

    [item] = response.json()["items"]
    assert item["travel_basis"] == "straight_line_estimate"
    assert item["route_provider"] == "haversine"
    assert item["travel_minutes"] > 0
    assert "Road routing was unavailable, so travel times are straight-line estimates." in response.json()["warnings"]


def test_public_transport_uses_a_commute_estimate(client, osrm) -> None:
    place(client, admin_headers(client), "Beach One")
    response = client.post(
        PATH, headers=user_headers(client),
        json={"interests": ["beach"], "origin": NEAR_A, "travel_mode": "public_transport"},
    )

    [item] = response.json()["items"]
    assert item["travel_basis"] == "commute_estimate"
    assert item["travel_mode"] == "public_transport"
    assert osrm.calls == 0


def test_no_start_point_keeps_travel_neutral(client, osrm) -> None:
    place(client, admin_headers(client), "Beach One")
    response = client.post(PATH, headers=user_headers(client), json={"interests": ["beach"]})

    [item] = response.json()["items"]
    assert item["travel_basis"] == "unknown"
    assert item["breakdown"]["travel"]["value"] == scoring.NEUTRAL
    assert "Set a start point on the map to rank places by travel time." in response.json()["warnings"]
    assert osrm.calls == 0


def test_saves_the_preference_signal(client, osrm) -> None:
    place(client, admin_headers(client), "Beach One")
    traveler = user_headers(client)
    response = client.post(PATH, headers=traveler, json={"interests": ["Beach"], "adult_count": 2})

    latest = client.get("/api/v1/recommendations/preferences/latest", headers=traveler).json()
    assert latest["preference_signal_id"] == response.json()["preference_signal_id"]
    assert latest["preferred_categories"] == ["beach"]
    assert latest["group_friendly"] is True


def test_top_places_share_the_route_rate_limit(client, osrm, monkeypatch) -> None:
    place(client, admin_headers(client), "Beach One")
    monkeypatch.setenv("ROUTE_REQUESTS_PER_MINUTE", "1")
    get_settings.cache_clear()
    traveler = user_headers(client)

    assert client.post(PATH, headers=traveler, json={"interests": ["beach"]}).status_code == 201
    limited = client.post(PATH, headers=traveler, json={"interests": ["beach"]})
    assert limited.status_code == 429
    assert limited.json()["error"]["code"] == "route_rate_limited"


def test_rejects_child_ages_outside_zero_to_seventeen(client, osrm) -> None:
    response = client.post(PATH, headers=user_headers(client), json={"child_ages": [18]})
    assert response.status_code == 422


# OSRM table parsing --------------------------------------------------------


def test_osrm_table_response_is_parsed() -> None:
    result = _parse_table_response(
        {
            "code": "Ok",
            "durations": [[600.0, None]],
            "distances": [[5000.0, None]],
            "sources": [{"distance": 3.5}],
            "destinations": [{"distance": 12.0}, {"distance": 40.0}],
        },
        expected_count=2,
    )
    assert result.source_snap_meters == 3.5
    assert result.entries[0] == OSRMTableEntry(600.0, 5000.0, 12.0)
    assert result.entries[1] == OSRMTableEntry(None, None, 40.0)


def test_osrm_table_response_must_match_the_request() -> None:
    with pytest.raises(OSRMClientError):
        _parse_table_response(
            {"durations": [[600.0]], "destinations": [{"distance": 1.0}]},
            expected_count=2,
        )
