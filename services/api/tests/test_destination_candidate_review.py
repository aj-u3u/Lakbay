import asyncio
import json
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import async_sessionmaker

from app.db.session import get_db_session
from app.features.destinations.models import DestinationCandidate
from scripts import stage_osm_destination_candidates as importer
from scripts.stage_osm_destination_candidates import load_candidates
from tests.test_phase2_destination_data import admin_headers, user_headers


def _stage_candidate(client, *, name: str = "Visitor Garden", lat: float = 7.1) -> int:
    async def insert() -> int:
        override = client.app.dependency_overrides[get_db_session]
        async for session in override():
            candidate = DestinationCandidate(
                osm_type="node",
                osm_id=710000001 if name == "Visitor Garden" else 710000002,
                osm_url="https://www.openstreetmap.org/node/710000001",
                source_area="Davao City",
                source_tag="leisure=garden",
                name=name,
                lat=lat,
                lng=125.6,
                suggested_category="garden",
            )
            session.add(candidate)
            await session.commit()
            await session.refresh(candidate)
            return candidate.candidate_id
        raise AssertionError("No test database session")

    return asyncio.run(insert())


def test_candidate_queue_is_admin_only(client) -> None:
    candidate_id = _stage_candidate(client)
    path = "/api/v1/admin/destination-candidates"
    assert client.get(path).status_code == 401
    assert client.get(path, headers=user_headers(client)).status_code == 403
    headers = admin_headers(client)
    response = client.get(path, headers=headers, params={"review_status": "staged"})
    assert response.status_code == 200
    assert [row["candidate_id"] for row in response.json()] == [candidate_id]
    assert response.json()[0]["suggested_category"] == "garden"
    assert client.get("/api/v1/destinations").json() == []


def test_admin_can_stage_one_special_case_without_publishing(client) -> None:
    path = "/api/v1/admin/destination-candidates"
    payload = {
        "osm_type": "node",
        "osm_id": 4385211700,
        "osm_url": "https://www.openstreetmap.org/node/4385211700",
        "source_area": "Davao Oriental",
        "source_tag": "natural=cape",
        "name": "Cape San Agustin",
        "lat": 6.2693185,
        "lng": 126.1929652,
        "suggested_category": "cape",
    }
    assert client.post(path, json=payload, headers=user_headers(client)).status_code == 403
    headers = admin_headers(client)
    invalid = client.post(path, json={**payload, "osm_url": "https://example.org/cape"}, headers=headers)
    assert invalid.status_code == 422
    created = client.post(path, json=payload, headers=headers)
    assert created.status_code == 201
    assert created.json()["review_status"] == "staged"
    assert created.json()["category"] is None
    assert client.post(path, json=payload, headers=headers).status_code == 409
    assert client.get("/api/v1/destinations").json() == []


def test_admin_adds_details_then_publishes_without_route_ready(client) -> None:
    candidate_id = _stage_candidate(client)
    headers = admin_headers(client)
    base = f"/api/v1/admin/destination-candidates/{candidate_id}"
    denied = client.post(f"{base}/publish", headers=headers)
    assert denied.status_code == 400
    assert denied.json()["error"]["code"] == "candidate_purpose_unverified"

    edited = client.patch(
        base,
        headers=headers,
        json={
            "category": "garden",
            "district": "Davao City",
            "visitor_purpose": "Public garden visits and photography",
            "vibes": "nature, relaxation",
            "activities": "walking, photography",
            "entrance_fee": "Unknown",
            "estimated_cost": None,
        },
    )
    assert edited.status_code == 200
    assert edited.json()["entrance_fee"] == "Unknown"
    assert edited.json()["vibes"] == "nature, relaxation"
    still_denied = client.post(f"{base}/publish", headers=headers)
    assert still_denied.json()["error"]["code"] == "candidate_access_unverified"

    verified = client.patch(
        base,
        headers=headers,
        json={
            "access_policy": "public",
            "access_source_url": "https://example.org/garden-access",
            "access_verified_at": datetime.now(timezone.utc).isoformat(),
        },
    )
    assert verified.status_code == 200
    published = client.post(f"{base}/publish", headers=headers)
    assert published.status_code == 200
    assert published.json()["review_status"] == "published"
    destination_id = published.json()["destination_id"]
    destination = client.get(f"/api/v1/destinations/{destination_id}").json()
    assert destination["name"] == "Visitor Garden"
    assert destination["activities"] == "walking, photography"
    assert destination["vibes"] == "nature, relaxation"
    assert destination["estimated_cost"] is None
    assert destination["route_ready"] is False
    assert destination["arrival_lat"] is None
    assert client.post(f"{base}/publish", headers=headers).status_code == 409


def test_nearby_existing_destination_blocks_publication(client) -> None:
    candidate_id = _stage_candidate(client)
    headers = admin_headers(client)
    existing = client.post(
        "/api/v1/destinations",
        headers=headers,
        json={"name": "Visitor Garden", "lat": 7.1005, "lng": 125.6},
    )
    assert existing.status_code == 201
    base = f"/api/v1/admin/destination-candidates/{candidate_id}"
    edited = client.patch(
        base,
        headers=headers,
        json={
            "category": "garden",
            "district": "Davao City",
            "visitor_purpose": "Garden visits",
            "access_policy": "public",
            "access_source_url": "https://example.org/access",
            "access_verified_at": datetime.now(timezone.utc).isoformat(),
        },
    )
    assert edited.status_code == 200
    publish = client.post(f"{base}/publish", headers=headers)
    assert publish.status_code == 409
    assert publish.json()["error"]["code"] == "candidate_duplicate_destination"


def test_reject_keeps_candidate_out_of_public_catalog(client) -> None:
    candidate_id = _stage_candidate(client)
    headers = admin_headers(client)
    base = f"/api/v1/admin/destination-candidates/{candidate_id}"
    rejected = client.post(f"{base}/reject", headers=headers, json={"reason": "Private property"})
    assert rejected.status_code == 200
    assert rejected.json()["review_status"] == "rejected"
    assert client.post(f"{base}/publish", headers=headers).status_code == 409
    assert client.get("/api/v1/destinations").json() == []


def test_importer_deduplicates_and_ignores_nonvisitor_rows(tmp_path) -> None:
    source = tmp_path / "review.jsonl"
    candidate = {
        "review_decision": "visitor_candidate_review",
        "osm_type": "node",
        "osm_id": 123,
        "osm_url": "https://www.openstreetmap.org/node/123",
        "latitude": 7.1,
        "longitude": 125.6,
    }
    excluded = {**candidate, "review_decision": "hold_restricted_or_closed", "osm_id": 124}
    source.write_text("\n".join(json.dumps(row) for row in [candidate, candidate, excluded]))
    result = load_candidates(source)
    assert len(result) == 1
    assert result[0]["osm_id"] == 123


def test_importer_stages_once_without_publishing(client, tmp_path, monkeypatch) -> None:
    source = tmp_path / "review.jsonl"
    source.write_text(
        json.dumps(
            {
                "review_decision": "visitor_candidate_review",
                "osm_type": "node",
                "osm_id": 345,
                "osm_url": "https://www.openstreetmap.org/node/345",
                "latitude": 7.1,
                "longitude": 125.6,
                "source_area": "Davao City",
                "source_tag": "tourism=museum",
                "name": "Test Museum",
                "suggested_category": "museum",
                "same_osm_id_in_multiple_areas": False,
                "exact_seed_name_match": False,
            }
        )
        + "\n",
        encoding="utf-8",
    )

    async def get_engine():
        generator = client.app.dependency_overrides[get_db_session]()
        session = await anext(generator)
        try:
            return session.bind
        finally:
            await generator.aclose()

    engine = asyncio.run(get_engine())
    monkeypatch.setattr(
        importer,
        "get_sessionmaker",
        lambda: async_sessionmaker(bind=engine, expire_on_commit=False),
    )
    assert asyncio.run(importer.stage(source)) == (1, 0)
    assert asyncio.run(importer.stage(source)) == (0, 1)
    response = client.get(
        "/api/v1/admin/destination-candidates",
        headers=admin_headers(client),
    )
    assert response.status_code == 200
    assert response.json()[0]["name"] == "Test Museum"
    assert response.json()[0]["review_status"] == "staged"
    assert client.get("/api/v1/destinations").json() == []


def _stage_many(client, rows: list[dict]) -> dict[str, int]:
    """Stage candidates with the given fields; returns candidate ids by name."""

    async def insert() -> dict[str, int]:
        override = client.app.dependency_overrides[get_db_session]
        ids: dict[str, int] = {}
        async for session in override():
            for index, row in enumerate(rows):
                osm_id = row.get("osm_id", 720000000 + index)
                candidate = DestinationCandidate(
                    osm_type="node",
                    osm_id=osm_id,
                    osm_url=f"https://www.openstreetmap.org/node/{osm_id}",
                    source_area=row.get("source_area", "Davao City"),
                    source_tag=row.get("source_tag", "tourism=attraction"),
                    name=row["name"],
                    lat=7.1,
                    lng=125.6,
                    suggested_category=row.get("suggested_category"),
                    district=row.get("district"),
                    location=row.get("location"),
                    review_notes=row.get("review_notes"),
                    review_status=row.get("review_status", "staged"),
                )
                session.add(candidate)
                await session.commit()
                await session.refresh(candidate)
                ids[row["name"]] = candidate.candidate_id
            return ids
        raise AssertionError("No test database session")

    return asyncio.run(insert())


SEARCH_ROWS = [
    {"name": "Baradi Falls", "district": "Marilog", "suggested_category": "waterfall", "osm_id": 6417207468},
    {"name": "Bemwa Farm", "location": "Datu Salumay, Marilog District", "suggested_category": "farm"},
    {"name": "Antag Falls", "district": "Toril", "suggested_category": "waterfall",
     "review_notes": "TEMPORARILY CLOSED per team update"},
    {"name": "Amador Inland Resort", "location": "Gumalang", "suggested_category": "resort"},
    {"name": "Old Pier", "district": "Samal", "review_status": "rejected"},
]


def _search(client, headers, q=None, **params):
    query = {"review_status": "staged", **params}
    if q is not None:
        query["q"] = q
    response = client.get("/api/v1/admin/destination-candidates", headers=headers, params=query)
    assert response.status_code == 200, response.text
    return [row["name"] for row in response.json()]


def test_candidate_search_matches_a_name_ignoring_case_and_partial_words(client) -> None:
    _stage_many(client, SEARCH_ROWS)
    headers = admin_headers(client)

    assert _search(client, headers, "baradi") == ["Baradi Falls"]
    assert _search(client, headers, "BEM") == ["Bemwa Farm"]
    assert sorted(_search(client, headers, "falls")) == ["Antag Falls", "Baradi Falls"]


def test_candidate_search_looks_in_district_location_category_notes_and_osm_id(client) -> None:
    _stage_many(client, SEARCH_ROWS)
    headers = admin_headers(client)

    assert sorted(_search(client, headers, "marilog")) == ["Baradi Falls", "Bemwa Farm"]  # district, location
    assert _search(client, headers, "resort") == ["Amador Inland Resort"]  # category
    assert _search(client, headers, "closed") == ["Antag Falls"]  # review notes
    assert _search(client, headers, "6417207468") == ["Baradi Falls"]  # OSM id


def test_candidate_search_requires_every_word_to_match(client) -> None:
    _stage_many(client, SEARCH_ROWS)
    headers = admin_headers(client)

    assert _search(client, headers, "marilog falls") == ["Baradi Falls"]
    assert _search(client, headers, "falls toril") == ["Antag Falls"]
    assert _search(client, headers, "marilog resort") == []


def test_candidate_search_keeps_the_status_filter_and_paging(client) -> None:
    _stage_many(client, SEARCH_ROWS)
    headers = admin_headers(client)

    assert _search(client, headers, "pier") == []  # rejected, not staged
    assert _search(client, headers, "pier", review_status="rejected") == ["Old Pier"]
    first = _search(client, headers, "a", limit=2, offset=0)
    second = _search(client, headers, "a", limit=2, offset=2)
    assert len(first) == 2 and set(first).isdisjoint(second)
    assert len(first) + len(second) == len(_search(client, headers, "a"))


def test_candidate_search_treats_wildcards_as_plain_text(client) -> None:
    _stage_many(client, SEARCH_ROWS)
    headers = admin_headers(client)

    assert _search(client, headers, "%") == []
    assert _search(client, headers, "_") == []
    assert _search(client, headers, "b%") == []  # would match everything if '%' were a wildcard


def test_empty_candidate_search_returns_the_whole_queue_and_long_text_is_rejected(client) -> None:
    _stage_many(client, SEARCH_ROWS)
    headers = admin_headers(client)

    everything = _search(client, headers)
    assert len(everything) == 4  # the rejected one is excluded by the status filter
    assert _search(client, headers, "   ") == everything
    too_long = client.get(
        "/api/v1/admin/destination-candidates",
        headers=headers,
        params={"q": "x" * 101},
    )
    assert too_long.status_code == 422


def test_candidate_search_is_admin_only(client) -> None:
    _stage_many(client, SEARCH_ROWS)
    path = "/api/v1/admin/destination-candidates"
    assert client.get(path, params={"q": "falls"}).status_code == 401
    assert client.get(path, headers=user_headers(client), params={"q": "falls"}).status_code == 403
