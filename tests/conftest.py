import asyncio
from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from geoalchemy2 import Geography
from sqlalchemy import event
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.core.config import get_settings
from app.features.ai.service import _ai_user_limiter
from app.features.memories.service import _cloudinary_upload_limiter
from app.features.routes.dependencies import _route_request_limiter
from app.db.base import Base, import_model_modules
from app.db.session import get_db_session
from app.main import create_app


TEST_DATABASE_URL = "sqlite+aiosqlite://"


@compiles(Geography, "sqlite")
def compile_geography_for_sqlite(type_, compiler, **kw) -> str:
    return "TEXT"


@pytest.fixture(autouse=True)
def clear_settings_cache() -> None:
    get_settings.cache_clear()
    _ai_user_limiter.clear()
    _cloudinary_upload_limiter.clear()
    _route_request_limiter.clear()
    yield
    get_settings.cache_clear()
    _ai_user_limiter.clear()
    _cloudinary_upload_limiter.clear()
    _route_request_limiter.clear()


@pytest.fixture
def client(monkeypatch) -> Generator[TestClient, None, None]:
    monkeypatch.setenv("DATABASE_URL", TEST_DATABASE_URL)
    monkeypatch.setenv("JWT_SECRET_KEY", "test-secret-key")
    monkeypatch.setenv("ADMIN_REGISTRATION_CODE", "admin-test-code")
    monkeypatch.setenv("CLOUDINARY_CLOUD_NAME", "demo")
    get_settings.cache_clear()
    import_model_modules()

    engine = create_async_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    event.listen(engine.sync_engine, "connect", register_sqlite_spatial_functions)
    TestingSessionLocal = async_sessionmaker(
        bind=engine,
        expire_on_commit=False,
        autoflush=False,
    )

    async def create_tables() -> None:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)

    async def drop_tables() -> None:
        async with engine.begin() as connection:
            await connection.run_sync(Base.metadata.drop_all)
        await engine.dispose()

    async def override_get_db_session():
        async with TestingSessionLocal() as session:
            try:
                yield session
            except Exception:
                await session.rollback()
                raise

    asyncio.run(create_tables())

    app = create_app()
    app.dependency_overrides[get_db_session] = override_get_db_session

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    asyncio.run(drop_tables())


def register_sqlite_spatial_functions(dbapi_connection, connection_record) -> None:
    dbapi_connection.create_function(
        "ST_GeogFromText",
        1,
        lambda value: value,
    )
    dbapi_connection.create_function(
        "AsBinary",
        1,
        lambda value: value,
    )
