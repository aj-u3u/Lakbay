from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.accommodations.models import Accommodation
from app.features.destinations.models import Destination
from app.features.transportations.models import Transportation


class PlanningRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_active_destinations(self, destination_ids: list[int]) -> list[Destination]:
        if not destination_ids:
            return []
        result = await self.session.execute(
            select(Destination).where(
                Destination.destination_id.in_(destination_ids),
                Destination.is_active.is_(True),
            ),
        )
        return list(result.scalars().all())

    async def list_available_accommodations(self, destination_ids: list[int]) -> list[Accommodation]:
        if not destination_ids:
            return []
        result = await self.session.execute(
            select(Accommodation).where(
                Accommodation.destination_id.in_(destination_ids),
                Accommodation.is_available.is_(True),
            ).order_by(Accommodation.accommodation_id),
        )
        return list(result.scalars().all())

    async def list_available_transportations(self, destination_ids: list[int]) -> list[Transportation]:
        if not destination_ids:
            return []
        result = await self.session.execute(
            select(Transportation).where(
                Transportation.destination_id.in_(destination_ids),
                Transportation.is_available.is_(True),
            ).order_by(Transportation.transportation_id),
        )
        return list(result.scalars().all())
