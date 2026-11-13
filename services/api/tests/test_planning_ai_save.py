"""The selected preview, generated option, and saved trip stay tied together."""

import asyncio
import importlib
import json

import pytest
from fastapi.testclient import TestClient
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.db.base import Base, import_model_modules
from app.db.session import get_db_session
from app.integrations.groq.client import get_groq_client
from app.main import create_app
from tests.conftest import register_sqlite_spatial_functions
from tests.test_phase5_ai_itineraries import (
    FakeGroqClient,
    admin_headers,
    configure_ai,
    create_destination,
    create_transportation,
    valid_ai_response,
)
from tests.test_phase6_routes import FakeOSRMClient
from tests.test_planning_preview import register
from tests.test_planning_routes import route_result


def test_planning_snapshot_migration_upgrades_and_downgrades(monkeypatch) -> None:
    migration = importlib.import_module(
        "app.db.migrations.versions.2026_10_18_0500_planning_trip_snapshot"
    )
    engine = create_engine("sqlite:///:memory:")
    with engine.begin() as connection:
        connection.execute(text("CREATE TABLE trips (trip_id INTEGER PRIMARY KEY)"))
        monkeypatch.setattr(migration, "op", Operations(MigrationContext.configure(connection)))
        migration.upgrade()
        assert "planning_snapshot" in {column["name"] for column in inspect(connection).get_columns("trips")}
        migration.downgrade()
        assert "planning_snapshot" not in {column["name"] for column in inspect(connection).get_columns("trips")}
    engine.dispose()


def _planning_request(destination_id: int, transportation_id: int) -> dict:
    option_id = f"transportation:{transportation_id}"
    state = {
        "origin": {"label": "Davao City", "lat": 7.07, "lng": 125.61},
        "destination_ids": [destination_id],
        "total_budget": "10000.00",
        "traveler_count": 1,
        "day_count": 1,
        "night_count": 0,
        "return_to_origin": False,
        "selected_transport_option_ids": [option_id],
        "transport_pricing": [{"option_id": option_id, "price_basis": "per_person"}],
        "route_preferences": {},
        "cost_allowances": [
            {"category": "destination", "destination_id": destination_id, "amount": "100.00"},
            {"category": "food", "amount": "200.00"},
        ],
    }
    return {
        "total_budget": "10000.00",
        "traveler_count": 1,
        "day_count": 1,
        "destination_ids": [destination_id],
        "transportation_ids": [transportation_id],
        "planning_state": state,
        "input_revision": 3,
        "allow_fallback": False,
    }


def _file_app(database_url: str):
    engine = create_async_engine(database_url, connect_args={"check_same_thread": False})
    event.listen(engine.sync_engine, "connect", register_sqlite_spatial_functions)
    session_factory = async_sessionmaker(engine, expire_on_commit=False, autoflush=False)

    async def session_override():
        async with session_factory() as session:
            try:
                yield session
            except Exception:
                await session.rollback()
                raise

    app = create_app()
    app.dependency_overrides[get_db_session] = session_override
    return app, engine


@pytest.mark.parametrize("optimize_order", [False, True], ids=["keep-order", "optimized"])
def test_three_stop_itinerary_follows_round_trip_through_save_and_reopen(
    client, monkeypatch, optimize_order,
) -> None:
    configure_ai(monkeypatch)
    # This test retries with the Groq fallback model, which itineraries skip by default.
    monkeypatch.setenv("GROQ_FALLBACK_FOR_ITINERARIES", "true")
    get_settings.cache_clear()
    admin = admin_headers(client)
    user = register(client)
    selected = [
        create_destination(client, headers=admin, name=f"Park {index}", lat=7.08 + index / 100,
                           lng=125.62, category="park", estimated_cost="100.00")["destination_id"]
        for index in range(3)
    ]
    expected = [selected[1], selected[2], selected[0]] if optimize_order else selected
    osrm = FakeOSRMClient(
        preview_result=route_result(1000, 2000, 3000, 4000),
        optimize_result=route_result(1000, 2000, 3000, 4000, stop_order=[0, 2, 3, 1]),
    )
    monkeypatch.setattr("app.features.ai.router.get_osrm_client", lambda: osrm)

    valid = json.loads(valid_ai_response(destination_id=expected[0], day_count=2))
    for option in valid["options"]:
        first, second = option["days"]
        activity = first["activities"][0]
        first["activities"] = [
            {**activity, "destination_id": expected[0]},
            {**activity, "destination_id": None},
        ]
        second["activities"] = [
            {**activity, "destination_id": destination_id}
            for destination_id in expected
        ]
        option["estimated_total_cost"] = "2500.00"
        # A response may list day two first. The traveler reviews by day number.
        option["days"] = [second, first]

    invalid = json.loads(json.dumps(valid))
    bad_activities = invalid["options"][-1]["days"][0]["activities"]
    bad_activities[0], bad_activities[1] = bad_activities[1], bad_activities[0]
    fake = FakeGroqClient([json.dumps(invalid), json.dumps(valid)])
    client.app.dependency_overrides[get_groq_client] = lambda: fake

    origin = {"label": "Our hotel", "lat": 7.07, "lng": 125.61}
    trip_inputs = {
        "total_budget": "10000.00", "traveler_count": 1,
        "day_count": 2, "destination_ids": selected,
    }
    generated = client.post(
        "/api/v1/ai/itineraries/generate", headers=user,
        json={
            **trip_inputs, "input_revision": 4, "allow_fallback": True,
            "planning_state": {
                **trip_inputs, "origin": origin, "night_count": 0,
                "return_to_origin": True,
                "selected_transport_option_ids": ["mode:personal_vehicle"],
                "route_preferences": {
                    "optimize_order": optimize_order, "road_access_confirmed": True,
                },
                "cost_allowances": [
                    {"category": "destination", "destination_id": place, "amount": "100.00"}
                    for place in selected
                ] + [
                    {"category": "food", "amount": "200.00"},
                    {"category": "transportation", "amount": "400.00"},
                ],
            },
        },
    )
    assert generated.status_code == 200, generated.text
    body = generated.json()
    assert body["planning_preview"]["route"]["status"] == "calculated"
    rejected, accepted = body["model_runs"]
    assert rejected["validation_status"] == "invalid"
    assert accepted["validation_status"] == "valid"
    assert body["selected_generation_run_id"] == accepted["ai_generation_run_id"]
    for call in fake.calls:
        prompt = json.loads(call["messages"][1]["content"])
        assert prompt["required_destination_visit_order"] == expected

    route = body["planning_preview"]["route"]["summary"]
    assert route["route_provider"] == "osrm"
    assert [stop["destination_id"] for stop in route["stops"]] == [None, *expected, None]
    assert len(route["legs"]) == 4
    assert route["arrival_points_verified"] is False
    for stop in (route["stops"][0], route["stops"][-1]):
        assert stop["is_origin"] is True
        assert (stop["name"], stop["lat"], stop["lng"]) == (origin["label"], origin["lat"], origin["lng"])

    option_number = 5
    assert [
        item["destination_id"]
        for day in sorted(body["options"][-1]["days"], key=lambda day: day["day"])
        for item in day["activities"]
    ] == [expected[0], None, *expected]
    save_path = "/api/v1/trips/from-ai-option"
    assert client.post(save_path, headers=user, json={
        "generation_run_id": rejected["ai_generation_run_id"], "option_number": option_number,
    }).status_code == 404
    saved = client.post(save_path, headers=user, json={
        "generation_run_id": body["selected_generation_run_id"], "option_number": option_number,
    })
    assert saved.status_code == 201, saved.text
    reopened = client.get(f"/api/v1/trips/{saved.json()['trip_id']}", headers=user)
    assert reopened.status_code == 200, reopened.text
    trip = reopened.json()
    assert trip["route"]["stops"] == route["stops"]
    leg_fields = (
        "order", "from_destination_id", "to_destination_id", "from_name", "to_name",
        "distance_km", "duration_minutes", "is_estimated", "steps",
    )
    assert trip["route"]["legs"] == [
        {field: leg[field] for field in leg_fields} for leg in route["legs"]
    ]
    assert trip["planning_snapshot"]["preview"]["route"]["summary"] == route
    assert [
        item["destination_id"]
        for day in sorted(trip["itinerary_days"], key=lambda day: day["day_number"])
        for item in day["activities"]
    ] == [expected[0], None, *expected]


def test_selected_ai_itinerary_costs_and_route_survive_app_restart(tmp_path, monkeypatch) -> None:
    database_url = f"sqlite+aiosqlite:///{(tmp_path / 'planning.db').as_posix()}"
    monkeypatch.setenv("DATABASE_URL", database_url)
    monkeypatch.setenv("JWT_SECRET_KEY", "test-secret-key")
    monkeypatch.setenv("ADMIN_REGISTRATION_CODE", "admin-test-code")
    configure_ai(monkeypatch)
    import_model_modules()
    first_app, first_engine = _file_app(database_url)

    async def create_tables():
        async with first_engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)

    asyncio.run(create_tables())
    with TestClient(first_app) as client:
        admin = register(client, admin=True)
        destination = create_destination(client, admin)
        destination_id = destination["destination_id"]
        transportation = create_transportation(
            client, destination_id=destination_id, headers=admin,
            route_to=destination["name"], charging_unit="per_person",
        )
        transport_id = transportation["transportation_id"]
        fake = FakeGroqClient([
            valid_ai_response(
                destination_id=destination_id, transportation_id=transport_id,
                day_count=1,
            )
        ])
        first_app.dependency_overrides[get_groq_client] = lambda: fake
        user = register(client)
        generated = client.post(
            "/api/v1/ai/itineraries/generate", headers=user,
            json=_planning_request(destination_id, transport_id),
        )
        assert generated.status_code == 200, generated.text
        body = generated.json()
        geo = json.loads(fake.calls[0]["messages"][1]["content"])["geo_analytics_context"]
        assert geo["selected_destination_ids"] == [destination_id]
        assert geo["budget_projection"]["total_estimate"] == "900.00"
        assert geo["route_summary"]["destination_order"] == [destination_id]
        assert geo["route_summary"]["is_estimated"] == body["planning_preview"]["route"]["summary"]["is_estimated"]
        assert geo["destination_groups"] == []
        assert len(body["options"]) == 5
        preview = body["planning_preview"]
        assert preview["budget"]["completeness"] == "complete"
        assert preview["budget"]["total_estimate"] == "900.00"
        assert preview["route"]["summary"] is not None
        rate_line = next(line for line in preview["budget"]["lines"] if line["category"] == "transportation")
        assert rate_line["reference_id"] == f"transportation:{transport_id}"
        assert rate_line["source"] == "catalog_price_with_verified_basis"
        assert any(line["source"] == "traveler_allowance" for line in preview["budget"]["lines"])

        saved = client.post(
            "/api/v1/trips/from-ai-option", headers=user,
            json={"generation_run_id": body["selected_generation_run_id"], "option_number": 3},
        )
        assert saved.status_code == 201, saved.text
        saved_body = saved.json()
        trip_id = saved_body["trip_id"]
        assert saved_body["title"] == "Beach option 3"
        assert saved_body["estimated_total_cost"] == "900.00"
        assert saved_body["planning_snapshot"]["preview"]["budget"] == preview["budget"]
        assert saved_body["route"] is not None
    asyncio.run(first_engine.dispose())

    get_settings.cache_clear()
    second_app, second_engine = _file_app(database_url)
    with TestClient(second_app) as client:
        reloaded = client.get(f"/api/v1/trips/{trip_id}", headers=user)
        assert reloaded.status_code == 200, reloaded.text
        trip = reloaded.json()
        assert trip["destinations"] == saved_body["destinations"]
        assert trip["itinerary_days"] == saved_body["itinerary_days"]
        assert trip["estimated_total_cost"] == saved_body["estimated_total_cost"]
        assert trip["planning_snapshot"] == saved_body["planning_snapshot"]
        assert {key: trip["route"][key] for key in ("stops", "legs", "total_distance_km", "total_duration_minutes")} == {
            key: saved_body["route"][key] for key in ("stops", "legs", "total_distance_km", "total_duration_minutes")
        }
    asyncio.run(second_engine.dispose())


def test_planning_generation_rejects_substituted_ids_and_save_requires_owner(client, monkeypatch) -> None:
    configure_ai(monkeypatch)
    admin = register(client, admin=True)
    first = create_destination(client, admin)
    second = create_destination(client, admin, name="Second Planning Stop")
    transport = create_transportation(
        client, destination_id=first["destination_id"], headers=admin,
        route_to=first["name"], charging_unit="per_person",
    )
    user = register(client)
    request = _planning_request(first["destination_id"], transport["transportation_id"])
    request["destination_ids"].append(second["destination_id"])
    request["planning_state"]["destination_ids"].append(second["destination_id"])
    request["planning_state"]["cost_allowances"].append(
        {"category": "destination", "destination_id": second["destination_id"], "amount": "100.00"}
    )
    fake = FakeGroqClient([
        valid_ai_response(
            destination_id=first["destination_id"],
            transportation_id=transport["transportation_id"], day_count=1,
        )
    ])
    client.app.dependency_overrides[get_groq_client] = lambda: fake
    rejected = client.post("/api/v1/ai/itineraries/generate", headers=user, json=request)
    assert rejected.status_code == 502
    assert rejected.json()["error"]["code"] == "ai_generation_failed"

    request["destination_ids"].pop()
    request["planning_state"]["destination_ids"].pop()
    request["planning_state"]["cost_allowances"].pop()
    fake.responses.append(valid_ai_response(
        destination_id=first["destination_id"], day_count=1,
    ))
    missing_rate = client.post("/api/v1/ai/itineraries/generate", headers=user, json=request)
    assert missing_rate.status_code == 502
    assert missing_rate.json()["error"]["code"] == "ai_generation_failed"

    fake.responses.append(valid_ai_response(
        destination_id=first["destination_id"],
        transportation_id=transport["transportation_id"], day_count=1,
    ))
    generated = client.post("/api/v1/ai/itineraries/generate", headers=user, json=request)
    assert generated.status_code == 200, generated.text
    run_id = generated.json()["selected_generation_run_id"]
    outsider = client.post(
        "/api/v1/auth/register",
        json={"full_name": "Another User", "email": "another@example.com", "password": "password123", "confirm_password": "password123"},
    )
    other_headers = {"Authorization": f"Bearer {outsider.json()['tokens']['access_token']}"}
    denied = client.post(
        "/api/v1/trips/from-ai-option", headers=other_headers,
        json={"generation_run_id": run_id, "option_number": 1},
    )
    assert denied.status_code == 404
    assert denied.json()["error"]["code"] == "planning_generation_not_found"
