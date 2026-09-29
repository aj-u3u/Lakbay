from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.memories.models import TripMemory
from app.features.trips.models import Trip, TripDestination, TripMember


class MemoryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_trip_with_members(self, *, trip_id: int) -> Trip | None:
        result = await self.session.execute(
            select(Trip)
            .where(Trip.trip_id == trip_id)
            .options(
                selectinload(Trip.members).selectinload(TripMember.user),
                selectinload(Trip.destinations).selectinload(TripDestination.destination),
            )
        )

        return result.scalar_one_or_none()

    async def list_memories(
        self,
        *,
        trip_id: int,
        include_deleted: bool,
        limit: int,
        offset: int,
    ) -> list[TripMemory]:
        statement = (
            select(TripMemory)
            .where(TripMemory.trip_id == trip_id)
            .options(*_memory_options())
            .order_by(TripMemory.created_at.desc(), TripMemory.trip_memory_id.desc())
            .offset(offset)
            .limit(limit)
        )

        if not include_deleted:
            statement = statement.where(TripMemory.status == "active")

        result = await self.session.execute(statement)

        return list(result.scalars().all())

    async def get_memory(
        self,
        *,
        trip_id: int,
        memory_id: int,
        include_deleted: bool = False,
    ) -> TripMemory | None:
        statement = (
            select(TripMemory)
            .where(
                TripMemory.trip_id == trip_id,
                TripMemory.trip_memory_id == memory_id,
            )
            .options(*_memory_options())
        )

        if not include_deleted:
            statement = statement.where(TripMemory.status == "active")

        result = await self.session.execute(statement)

        return result.scalar_one_or_none()

    async def add_memory(self, memory: TripMemory) -> TripMemory:
        self.session.add(memory)
        await self.session.flush()

        return memory


def _memory_options():
    return (
        selectinload(TripMemory.uploaded_by_member).selectinload(TripMember.user),
        selectinload(TripMemory.destination),
    )
