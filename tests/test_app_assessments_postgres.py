"""Opt-in PostgreSQL rehearsal for the completed-trip assessment migration.

Run only against a dedicated, disposable local database. The fixture creates
the three prerequisite tables because a local PostgreSQL install may not have
PostGIS, which an older migration in the full chain requires.
"""

import asyncio
import importlib
import os
from urllib.parse import urlsplit

import pytest
from alembic.migration import MigrationContext
from alembic.operations import Operations
from httpx import ASGITransport, AsyncClient
from sqlalchemy import inspect, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import get_settings
from app.core.security import create_access_token
from app.db.base import Base
from app.db.session import get_db_session
from app.features.trips.models import Trip, TripMember
from app.features.users.models import User
from app.main import create_app


DATABASE_ENV = "LAKBAY_ASSESSMENT_TEST_DATABASE_URL"
MIGRATION = importlib.import_module(
    "app.db.migrations.versions.2026_11_09_0900_app_assessments"
)


def _run_migration(sync_connection, action: str) -> None:
    original_op = MIGRATION.op
    MIGRATION.op = Operations(MigrationContext.configure(sync_connection))
    try:
        getattr(MIGRATION, action)()
    finally:
        MIGRATION.op = original_op


def _assert_upgraded(sync_connection) -> None:
    inspector = inspect(sync_connection)
    assert inspector.has_table("app_assessments")
    assert {
        "uq_app_assessments_trip_user"
    } <= {constraint["name"] for constraint in inspector.get_unique_constraints("app_assessments")}
    assert {
        "fk_app_assessments_member_same_trip"
    } <= {constraint["name"] for constraint in inspector.get_foreign_keys("app_assessments")}


async def _run_rehearsal(database_url: str) -> None:
    engine = create_async_engine(database_url, poolclass=NullPool)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    prerequisite_tables = [User.__table__, Trip.__table__, TripMember.__table__]

    try:
        async with engine.begin() as connection:
            await connection.run_sync(
                lambda sync_connection: Base.metadata.create_all(
                    sync_connection, tables=prerequisite_tables, checkfirst=False
                )
            )
            await connection.run_sync(lambda sync_connection: _run_migration(sync_connection, "upgrade"))
            await connection.run_sync(_assert_upgraded)

        async with session_factory() as session:
            owner = User(
                full_name="Assessment Owner",
                email="assessment-owner@local.test",
                password_hash="test-only",
                role="user",
            )
            admin = User(
                full_name="Assessment Admin",
                email="assessment-admin@local.test",
                password_hash="test-only",
                role="admin",
            )
            outsider = User(
                full_name="Assessment Outsider",
                email="assessment-outsider@local.test",
                password_hash="test-only",
                role="user",
            )
            session.add_all([owner, admin, outsider])
            await session.flush()
            trip = Trip(owner_user_id=owner.user_id, title="Postgres rehearsal")
            session.add(trip)
            await session.flush()
            session.add(TripMember(trip_id=trip.trip_id, user_id=owner.user_id, role="owner"))
            await session.commit()
            trip_id = trip.trip_id
            owner_id, admin_id, outsider_id = owner.user_id, admin.user_id, outsider.user_id

        async def override_session():
            async with session_factory() as session:
                yield session

        app = create_app()
        app.dependency_overrides[get_db_session] = override_session
        settings = get_settings()
        owner_token = create_access_token(user_id=owner_id, role="user", settings=settings)
        admin_token = create_access_token(user_id=admin_id, role="admin", settings=settings)
        outsider_token = create_access_token(user_id=outsider_id, role="user", settings=settings)
        owner_headers = {"Authorization": f"Bearer {owner_token}"}
        admin_headers = {"Authorization": f"Bearer {admin_token}"}
        outsider_headers = {"Authorization": f"Bearer {outsider_token}"}
        path = f"/api/v1/trips/{trip_id}/app-assessment"
        payload = {
            "functional_suitability_rating": 5,
            "information_accuracy_rating": 4,
            "performance_rating": 3,
            "interaction_rating": 4,
            "reliability_rating": 5,
            "sharing_clarity_rating": None,
            "comment": "Local PostgreSQL rehearsal",
        }

        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://testserver") as client:
            assert (await client.get(f"{path}/me", headers=owner_headers)).json() == {
                "assessment": None
            }
            assert (await client.post(path, headers=owner_headers, json=payload)).status_code == 400
            assert (await client.get(f"{path}/me", headers=outsider_headers)).status_code == 404

            async with session_factory() as session:
                trip = await session.get(Trip, trip_id)
                assert trip is not None
                trip.status = "completed"
                await session.commit()

            submitted = await client.post(path, headers=owner_headers, json=payload)
            assert submitted.status_code == 201, submitted.text
            assert submitted.json()["sharing_clarity_rating"] is None
            assert (await client.post(path, headers=owner_headers, json=payload)).status_code == 409
            assert (await client.get(f"{path}/me", headers=owner_headers)).json()[
                "assessment"
            ]["app_assessment_id"] == submitted.json()["app_assessment_id"]
            assert (
                await client.get("/api/v1/evaluation/app-assessments/summary", headers=owner_headers)
            ).status_code == 403
            summary = await client.get(
                "/api/v1/evaluation/app-assessments/summary", headers=admin_headers
            )
            assert summary.status_code == 200, summary.text
            assert summary.json()["response_count"] == 1
            assert summary.json()["participant_count"] == 1
            assert summary.json()["questions"]["performance_rating"]["average"] == 3.0
            assert summary.json()["questions"]["sharing_clarity_rating"]["not_applicable"] == 1
            listed = await client.get("/api/v1/evaluation/app-assessments", headers=admin_headers)
            assert listed.status_code == 200, listed.text
            assert listed.json()["total"] == 1
            assert "user_id" not in listed.json()["items"][0]
            assert "trip_id" not in listed.json()["items"][0]

        for invalid_sql in (
            "INSERT INTO app_assessments (trip_id, user_id, question_version, performance_rating) "
            f"VALUES ({trip_id}, {owner_id}, 1, 6)",
            "INSERT INTO app_assessments (trip_id, user_id, question_version, performance_rating) "
            f"VALUES ({trip_id}, {outsider_id}, 1, 3)",
        ):
            with pytest.raises(IntegrityError):
                async with engine.begin() as connection:
                    await connection.execute(text(invalid_sql))

        async with engine.begin() as connection:
            await connection.run_sync(lambda sync_connection: _run_migration(sync_connection, "downgrade"))
            assert not await connection.run_sync(
                lambda sync_connection: inspect(sync_connection).has_table("app_assessments")
            )
            assert await connection.run_sync(
                lambda sync_connection: inspect(sync_connection).has_table("trips")
            )
    finally:
        await engine.dispose()


@pytest.mark.skipif(not os.getenv(DATABASE_ENV), reason=f"{DATABASE_ENV} is not set")
def test_app_assessment_migration_and_api_on_postgres(monkeypatch) -> None:
    database_url = os.environ[DATABASE_ENV]
    parsed = urlsplit(database_url)
    assert parsed.scheme == "postgresql+asyncpg"
    assert parsed.hostname in {"localhost", "127.0.0.1"}
    assert parsed.path == "/lakbay_assessment_rehearsal"
    monkeypatch.setenv("DATABASE_URL", database_url)
    monkeypatch.setenv("JWT_SECRET_KEY", "local-postgres-rehearsal-secret")
    get_settings.cache_clear()
    try:
        asyncio.run(_run_rehearsal(database_url))
    finally:
        get_settings.cache_clear()
