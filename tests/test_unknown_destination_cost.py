import asyncio

from sqlalchemy import event, func, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.db.base import Base, import_model_modules
from app.features.destinations.models import Destination
from app.features.destinations.schemas import DestinationCreate
from app.seeds import davao_destinations as seed_module
from tests.conftest import register_sqlite_spatial_functions


def _headers(client, *, admin: bool) -> dict[str, str]:
    email = "unknown-cost-admin@example.com" if admin else "unknown-cost-user@example.com"
    path = "/api/v1/auth/register/admin" if admin else "/api/v1/auth/register"
    payload = {
        "full_name": "Catalog Admin" if admin else "Catalog Traveler",
        "email": email,
        "password": "password123",
        "confirm_password": "password123",
    }
    if admin:
        payload["admin_registration_code"] = "admin-test-code"
    response = client.post(path, json=payload)
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def test_unknown_cost_is_distinct_from_free_and_blocks_budget_estimate(client) -> None:
    admin = _headers(client, admin=True)
    traveler = _headers(client, admin=False)
    created = client.post(
        "/api/v1/destinations",
        headers=admin,
        json={
            "name": "Unpriced Park",
            "district": "Davao del Sur",
            "lat": 6.77553,
            "lng": 125.34392,
            "entrance_fee": "Unknown; confirm with operator.",
        },
    )
    assert created.status_code == 201
    destination_id = created.json()["destination_id"]
    assert created.json()["estimated_cost"] is None

    budget = client.post(
        "/api/v1/budgets/estimate",
        headers=traveler,
        json={
            "total_budget": "1000.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [destination_id],
        },
    )
    assert budget.status_code == 422
    assert budget.json()["error"]["code"] == "destination_cost_unknown"
    assert budget.json()["error"]["details"]["destination_ids"] == [destination_id]

    free = client.patch(
        f"/api/v1/destinations/{destination_id}",
        headers=admin,
        json={"estimated_cost": "0.00"},
    )
    assert free.status_code == 200
    assert free.json()["estimated_cost"] == "0.00"

    unknown_again = client.patch(
        f"/api/v1/destinations/{destination_id}",
        headers=admin,
        json={"estimated_cost": None},
    )
    assert unknown_again.status_code == 200
    assert unknown_again.json()["estimated_cost"] is None


def test_unknown_cost_is_visible_for_browsing_but_not_budget_filtered_recommendations(client) -> None:
    admin = _headers(client, admin=True)
    traveler = _headers(client, admin=False)
    created = client.post(
        "/api/v1/destinations",
        headers=admin,
        json={
            "name": "Unpriced Nature Site",
            "district": "Davao del Norte",
            "category": "nature park",
            "vibes": "nature",
            "lat": 7.26989,
            "lng": 125.68049,
        },
    )
    assert created.status_code == 201
    destination_id = created.json()["destination_id"]
    listing = client.get("/api/v1/destinations?district=Davao%20del%20Norte")
    assert listing.status_code == 200
    assert listing.json()[0]["estimated_cost"] is None

    preview = client.post(
        "/api/v1/planning/preview",
        headers=traveler,
        json={"state": {"destination_ids": [destination_id]}},
    )
    assert preview.status_code == 200
    assert preview.json()["destinations"][0]["catalog_estimated_cost"] is None

    unpriced = client.post(
        "/api/v1/recommendations",
        headers=traveler,
        json={"preferred_categories": ["nature park"]},
    )
    assert unpriced.status_code == 201
    assert unpriced.json()["recommendations"][0]["estimated_cost"] is None

    constrained = client.post(
        "/api/v1/recommendations",
        headers=traveler,
        json={"preferred_categories": ["nature park"], "max_estimated_cost": "100.00"},
    )
    assert constrained.status_code == 201
    assert all(
        item["destination_id"] != destination_id
        for item in constrained.json()["recommendations"]
    )


def test_discovery_seed_is_reviewed_and_idempotent(monkeypatch) -> None:
    rows = seed_module.DISCOVERY_VISITOR_DESTINATIONS
    assert len(rows) == 4
    assert len({row["name"] for row in rows}) == 4
    assert {row["district"] for row in rows} == {
        "Davao del Norte", "Davao del Sur", "Davao Oriental"
    }
    for row in rows:
        DestinationCreate.model_validate({
            key: value for key, value in row.items()
            if key not in {"accommodations", "transportations"}
        })
        assert row["estimated_cost"] is None
        assert row["route_ready"] is False
        assert row["accommodations"] == row["transportations"] == []

    import_model_modules()
    engine = create_async_engine(
        "sqlite+aiosqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    event.listen(engine.sync_engine, "connect", register_sqlite_spatial_functions)
    sessionmaker = async_sessionmaker(engine, expire_on_commit=False, autoflush=False)
    monkeypatch.setattr(seed_module, "get_sessionmaker", lambda: sessionmaker)

    async def exercise() -> None:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        await seed_module.seed(rows)
        await seed_module.seed(rows)
        async with sessionmaker() as session:
            assert await session.scalar(select(func.count()).select_from(Destination)) == 4
            destinations = list((await session.execute(select(Destination))).scalars())
            assert all(
                item.estimated_cost is None
                and not item.route_ready
                and item.arrival_lat is None
                for item in destinations
            )
        await engine.dispose()

    asyncio.run(exercise())


def test_group_scoring_excludes_unknown_cost_without_calling_it_free(client) -> None:
    admin = _headers(client, admin=True)
    traveler = _headers(client, admin=False)
    ids = []
    for name, cost in (("Priced Group Stop", "100.00"), ("Unknown Group Stop", None)):
        response = client.post(
            "/api/v1/destinations",
            headers=admin,
            json={
                "name": name,
                "district": "Davao del Norte",
                "lat": 7.26989,
                "lng": 125.68049,
                "estimated_cost": cost,
            },
        )
        assert response.status_code == 201
        ids.append(response.json()["destination_id"])

    response = client.post(
        "/api/v1/geo-analytics/destination-groups",
        headers=traveler,
        json={"destination_ids": ids, "group_size": 2},
    )
    assert response.status_code == 200
    assert response.json()["groups"] == []
    assert any("unknown costs" in item for item in response.json()["warnings"])


def test_coverage_completion_seed_has_eight_distinct_unpriced_attractions(monkeypatch) -> None:
    rows = seed_module.COVERAGE_COMPLETION_DESTINATIONS
    assert len(rows) == 8
    assert len({row["name"] for row in rows}) == 8
    prior_names = {
        row["name"] for row in (
            seed_module.SEED_DESTINATIONS
            + seed_module.CURATED_VISITOR_DESTINATIONS
            + seed_module.DISCOVERY_VISITOR_DESTINATIONS
        )
    }
    assert not prior_names.intersection(row["name"] for row in rows)
    assert [row["district"] for row in rows].count("Davao del Sur") == 1
    assert [row["district"] for row in rows].count("Davao Oriental") == 1
    assert [row["district"] for row in rows].count("Davao de Oro") == 3
    assert [row["district"] for row in rows].count("Davao Occidental") == 3
    for row in rows:
        DestinationCreate.model_validate({
            key: value for key, value in row.items()
            if key not in {"accommodations", "transportations"}
        })
        assert 5.0 <= row["lat"] <= 9.0
        assert 124.0 <= row["lng"] <= 127.0
        assert row["estimated_cost"] is None
        assert row["route_ready"] is False
        assert row["accommodations"] == row["transportations"] == []

    import_model_modules()
    engine = create_async_engine(
        "sqlite+aiosqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    event.listen(engine.sync_engine, "connect", register_sqlite_spatial_functions)
    sessionmaker = async_sessionmaker(engine, expire_on_commit=False, autoflush=False)
    monkeypatch.setattr(seed_module, "get_sessionmaker", lambda: sessionmaker)

    async def exercise() -> None:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        await seed_module.seed(rows)
        await seed_module.seed(rows)
        async with sessionmaker() as session:
            assert await session.scalar(select(func.count()).select_from(Destination)) == 8
            assert all(
                item.estimated_cost is None and item.arrival_lat is None
                for item in (await session.execute(select(Destination))).scalars()
            )
        await engine.dispose()

    asyncio.run(exercise())
