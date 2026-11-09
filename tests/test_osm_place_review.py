"""OSM suggestions stay reviewable and never modify the public catalog by themselves."""

import asyncio

import httpx

from app.core.exceptions import LakbayAPIError
from app.core.config import get_settings
from app.features.destinations.osm_lookup import OSMLookupService
from app.integrations.osm.client import SEARCH_RESULT_CAP, OSMClient, name_pattern
from tests.test_destination_candidate_review import _stage_candidate
from tests.test_phase2_destination_data import admin_headers, user_headers


OSM_ROW = {
    "type": "node", "id": 710000001, "lat": 7.1, "lon": 125.6,
    "tags": {
        "name": "Visitor Garden", "leisure": "garden",
        "description": "A public garden", "opening_hours": "Mo-Su 08:00-17:00",
        "addr:city": "Davao City", "fee": "yes", "website": "https://example.org",
    },
}
CANDIDATES = "/api/v1/admin/destination-candidates"


class FakeOverpass:
    """Stands in for httpx.AsyncClient; repeats the last response once the list runs out."""

    def __init__(self, responses: list[httpx.Response]) -> None:
        self.responses = list(responses)
        self.posts: list[str] = []
        self.client_kwargs: list[dict] = []

    def factory(self, **kwargs):
        self.client_kwargs.append(kwargs)
        return self

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return None

    async def post(self, url, *, data, timeout):
        self.posts.append(data["data"])
        return self.responses.pop(0) if len(self.responses) > 1 else self.responses[0]


def test_search_requires_admin_and_returns_reviewable_matches(client, monkeypatch) -> None:
    async def fake_search(self, **kwargs):
        assert kwargs == {"name": "Visitor Garden", "lat": 7.1, "lng": 125.6, "radius_m": 3000}
        return [OSM_ROW, {**OSM_ROW, "id": 2, "tags": {"name": "Other place"}}]

    monkeypatch.setattr(OSMClient, "search", fake_search)
    path = "/api/v1/admin/destination-candidates/osm/search"
    params = {"name": "Visitor Garden", "lat": 7.1, "lng": 125.6}
    headers = admin_headers(client)
    assert client.get(path, params=params).status_code == 401
    assert client.get(path, params=params, headers=user_headers(client)).status_code == 403
    assert client.get(path, params={**params, "radius_m": 50000}, headers=headers).status_code == 422
    assert client.get(path, params={**params, "name": "  "}, headers=headers).json()["error"]["code"] == "invalid_osm_search"
    candidate_id = _stage_candidate(client)
    result = client.get(path, params=params, headers=headers)
    assert result.status_code == 200
    assert result.json()[0]["existing_candidate_id"] == candidate_id
    assert result.json()[0]["source_tag"] == "leisure=garden"
    assert client.get("/api/v1/destinations").json() == []


def test_staged_suggestions_show_current_and_source_without_saving(client, monkeypatch) -> None:
    async def fake_get(self, osm_type, osm_id):
        assert (osm_type, osm_id) == ("node", 710000001)
        return OSM_ROW

    monkeypatch.setattr(OSMClient, "get", fake_get)
    candidate_id = _stage_candidate(client)
    headers = admin_headers(client)
    base = f"/api/v1/admin/destination-candidates/{candidate_id}"
    before = client.get(base, headers=headers).json()
    result = client.get(f"{base}/osm-suggestions", headers=headers)
    assert result.status_code == 200
    body = result.json()
    fields = {item["field"]: item for item in body["suggestions"]}
    assert fields["name"]["current_value"] == "Visitor Garden"
    assert fields["operating_hours"]["source_tag"] == "opening_hours"
    assert fields["operating_hours"]["source_url"] == before["osm_url"]
    assert body["fee_hint"] == "yes"
    # leisure=garden has no catalog category equivalent, so it is only a hint.
    assert body["category_hint"] == "leisure=garden"
    assert "category" not in fields
    assert "estimated_cost" not in fields
    assert "entrance_fee" not in fields
    assert "arrival_lat" not in fields
    assert client.get(base, headers=headers).json() == before
    assert client.get("/api/v1/destinations").json() == []
    accepted = client.patch(base, headers=headers, json={"operating_hours": fields["operating_hours"]["value"]})
    assert accepted.status_code == 200
    assert accepted.json()["operating_hours"] == "Mo-Su 08:00-17:00"
    assert client.get("/api/v1/destinations").json() == []


def test_new_place_suggestions_are_read_only(client, monkeypatch) -> None:
    async def fake_get(self, osm_type, osm_id):
        return {**OSM_ROW, "id": 923, "tags": {"name": "New Beach", "natural": "beach"}}

    monkeypatch.setattr(OSMClient, "get", fake_get)
    headers = admin_headers(client)
    result = client.get(
        "/api/v1/admin/destination-candidates/osm/node/923/suggestions", headers=headers
    )
    assert result.status_code == 200
    assert result.json()["candidate_id"] is None
    fields = {item["field"]: item for item in result.json()["suggestions"]}
    assert set(fields) == {"name", "lat", "lng", "category"}
    assert fields["category"]["value"] == "beach"
    assert fields["category"]["source_tag"] == "natural=beach"
    assert client.get("/api/v1/destinations").json() == []
    assert client.get("/api/v1/admin/destination-candidates", headers=headers).json() == []


def test_osm_failure_and_invalid_response_are_controlled(monkeypatch) -> None:
    class FailingClient:
        async def __aenter__(self):
            return self
        async def __aexit__(self, *args):
            return None
        async def post(self, *args, **kwargs):
            raise httpx.ConnectError("offline")

    monkeypatch.setattr("app.integrations.osm.client.httpx.AsyncClient", lambda **kwargs: FailingClient())
    try:
        asyncio.run(OSMClient().get("node", 999))
    except LakbayAPIError as exc:
        assert exc.code == "osm_unavailable"
        assert exc.status_code == 503
    else:
        raise AssertionError("Expected controlled OSM error")


def test_missing_osm_place_does_not_change_candidate(client, monkeypatch) -> None:
    async def fake_get(self, osm_type, osm_id):
        return None

    monkeypatch.setattr(OSMClient, "get", fake_get)
    candidate_id = _stage_candidate(client)
    headers = admin_headers(client)
    result = client.get(f"/api/v1/admin/destination-candidates/{candidate_id}/osm-suggestions", headers=headers)
    assert result.status_code == 404
    assert result.json()["error"]["code"] == "osm_place_not_found"
    assert client.get("/api/v1/destinations").json() == []


def test_only_provider_calls_count_toward_osm_rate_limit(client, monkeypatch) -> None:
    fake = FakeOverpass([httpx.Response(200, json={"elements": [OSM_ROW]})])
    monkeypatch.setattr("app.integrations.osm.client.httpx.AsyncClient", fake.factory)
    monkeypatch.setenv("OVERPASS_REQUESTS_PER_MINUTE", "1")
    get_settings.cache_clear()
    headers = admin_headers(client)
    base = "/api/v1/admin/destination-candidates/osm/node"
    assert client.get(f"{base}/710000001/suggestions", headers=headers).status_code == 200
    # A repeat view is served from the cache and does not use the admin's quota.
    assert client.get(f"{base}/710000001/suggestions", headers=headers).status_code == 200
    assert len(fake.posts) == 1
    limited = client.get(f"{base}/710000002/suggestions", headers=headers)
    assert limited.status_code == 429
    assert limited.json()["error"]["code"] == "osm_lookup_rate_limited"
    assert len(fake.posts) == 1


def test_invalid_provider_payload_is_a_gateway_error(monkeypatch) -> None:
    class InvalidClient:
        async def __aenter__(self):
            return self
        async def __aexit__(self, *args):
            return None
        async def post(self, *args, **kwargs):
            return httpx.Response(200, json={"unexpected": True})

    monkeypatch.setattr("app.integrations.osm.client.httpx.AsyncClient", lambda **kwargs: InvalidClient())
    try:
        asyncio.run(OSMClient().get("node", 991))
    except LakbayAPIError as exc:
        assert exc.code == "osm_invalid_response"
        assert exc.status_code == 502
    else:
        raise AssertionError("Expected controlled invalid response error")


def test_search_query_is_bounded_and_needs_no_escape_sequences(monkeypatch) -> None:
    fake = FakeOverpass([httpx.Response(200, json={"elements": []})])
    monkeypatch.setattr("app.integrations.osm.client.httpx.AsyncClient", fake.factory)
    asyncio.run(OSMClient().search(
        name=' Santo Niño "Park" (Main)\n', lat=7.1, lng=125.6, radius_m=3000,
    ))
    query = fake.posts[0]
    # Spaces and accented letters are sent as-is; regex operators and quotes become ".".
    assert 'nwr(around:3000,7.1000000,125.6000000)["name"~"Santo Niño .Park. .Main.",i];' in query
    assert "\\" not in query
    assert query.endswith(f"out center {SEARCH_RESULT_CAP};")
    assert fake.client_kwargs[0]["headers"]["User-Agent"].startswith("Lakbay")
    assert name_pattern(r"""a.b*c[d]e\f"g'h""") == "a.b.c.d.e.f.g.h"


def test_busy_overpass_is_retried_with_backoff(monkeypatch) -> None:
    fake = FakeOverpass([httpx.Response(502), httpx.Response(200, json={"elements": [OSM_ROW]})])
    delays = []

    async def no_sleep(delay):
        delays.append(delay)

    monkeypatch.setattr("app.integrations.osm.client.httpx.AsyncClient", fake.factory)
    monkeypatch.setattr("app.integrations.osm.client._sleep", no_sleep)
    row = asyncio.run(OSMClient().get("node", 710000001))
    assert row["id"] == 710000001
    assert len(fake.posts) == 2
    assert delays == [1.0]


def test_overpass_that_stays_busy_is_a_controlled_error(monkeypatch) -> None:
    fake = FakeOverpass([httpx.Response(502, text="at capacity")])
    delays = []

    async def no_sleep(delay):
        delays.append(delay)

    monkeypatch.setattr("app.integrations.osm.client.httpx.AsyncClient", fake.factory)
    monkeypatch.setattr("app.integrations.osm.client._sleep", no_sleep)
    try:
        asyncio.run(OSMClient().get("node", 993))
    except LakbayAPIError as exc:
        assert exc.code == "osm_unavailable"
        assert exc.status_code == 503
        assert "busy" in exc.message
    else:
        raise AssertionError("Expected controlled busy error")
    assert len(fake.posts) == 3
    assert delays == [1.0, 2.0]


def test_search_lists_exact_name_then_nearest_and_trims_before_lookups(client, monkeypatch) -> None:
    far_exact = {**OSM_ROW, "id": 1, "lat": 7.12}
    near_others = [
        {**OSM_ROW, "id": 100 + index, "lat": 7.1 + index * 0.0005,
         "tags": {"name": f"Visitor Garden {index}"}}
        for index in range(15)
    ]

    async def fake_search(self, **kwargs):
        return [*near_others, far_exact]

    monkeypatch.setattr(OSMClient, "search", fake_search)
    result = client.get(
        f"{CANDIDATES}/osm/search",
        params={"name": "visitor garden", "lat": 7.1, "lng": 125.6},
        headers=admin_headers(client),
    )
    assert result.status_code == 200
    ids = [item["osm_id"] for item in result.json()]
    assert ids == [1, *range(100, 109)]


def test_reviewed_or_missing_candidate_fails_before_any_osm_call(client, monkeypatch) -> None:
    calls = []

    async def fake_get(self, osm_type, osm_id):
        calls.append(osm_id)
        return OSM_ROW

    monkeypatch.setattr(OSMClient, "get", fake_get)
    candidate_id = _stage_candidate(client)
    headers = admin_headers(client)
    rejected = client.post(
        f"{CANDIDATES}/{candidate_id}/reject", headers=headers, json={"reason": "Private property"}
    )
    assert rejected.status_code == 200
    result = client.get(f"{CANDIDATES}/{candidate_id}/osm-suggestions", headers=headers)
    assert result.status_code == 409
    assert result.json()["error"]["code"] == "candidate_not_staged"
    missing = client.get(f"{CANDIDATES}/999999/osm-suggestions", headers=headers)
    assert missing.status_code == 404
    assert missing.json()["error"]["code"] == "candidate_not_found"
    assert calls == []
