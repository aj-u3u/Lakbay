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
            "activities": "walking, photography",
            "entrance_fee": "Unknown",
            "estimated_cost": None,
        },
    )
    assert edited.status_code == 200
    assert edited.json()["entrance_fee"] == "Unknown"
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
