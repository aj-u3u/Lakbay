import asyncio

from sqlalchemy import event, func, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.db.base import Base, import_model_modules
from app.features.accommodations.models import Accommodation
from app.features.destinations.models import Destination
from app.features.destinations.schemas import DestinationCreate
from app.features.transportations.models import Transportation
from app.seeds import davao_destinations as seed_module
from tests.conftest import register_sqlite_spatial_functions


def test_curated_visitor_seed_is_valid_isolated_and_idempotent(monkeypatch) -> None:
    rows = seed_module.CURATED_VISITOR_DESTINATIONS
    assert len(rows) == 5
    assert len({row["name"] for row in rows}) == len(rows)
    assert not {row["name"] for row in rows} & {
        row["name"] for row in seed_module.SEED_DESTINATIONS
    }
    for row in rows:
        DestinationCreate.model_validate({
            key: value for key, value in row.items()
            if key not in {"accommodations", "transportations"}
        })
        assert row["route_ready"] is False
        assert row["accommodations"] == []
        assert row["transportations"] == []
        assert 5.0 <= row["lat"] <= 9.0
        assert 124.0 <= row["lng"] <= 127.0

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
            destinations = list((await session.execute(select(Destination))).scalars())
            assert {item.name for item in destinations} == {row["name"] for row in rows}
            assert all(not item.route_ready and item.arrival_lat is None for item in destinations)
            assert (await session.scalar(select(func.count()).select_from(Accommodation))) == 0
            assert (await session.scalar(select(func.count()).select_from(Transportation))) == 0
        await engine.dispose()

    asyncio.run(exercise())
