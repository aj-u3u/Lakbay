from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.accommodations.models import Accommodation
from app.features.destinations.models import Destination
from app.features.transportations.models import Transportation


class BudgetRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_active_destinations_by_ids(
        self,
        destination_ids: list[int],
    ) -> list[Destination]:
        result = await self.session.execute(
            select(Destination).where(
                Destination.destination_id.in_(destination_ids),
                Destination.is_active.is_(True),
            )
        )

        return list(result.scalars().all())

    async def list_available_accommodations_by_ids(
        self,
        accommodation_ids: list[int],
    ) -> list[Accommodation]:
        if not accommodation_ids:
            return []

        result = await self.session.execute(
            select(Accommodation).where(
                Accommodation.accommodation_id.in_(accommodation_ids),
                Accommodation.is_available.is_(True),
            )
        )

        return list(result.scalars().all())

    async def list_available_transportations_by_ids(
        self,
        transportation_ids: list[int],
    ) -> list[Transportation]:
        if not transportation_ids:
            return []

        result = await self.session.execute(
            select(Transportation).where(
                Transportation.transportation_id.in_(transportation_ids),
                Transportation.is_available.is_(True),
            )
        )

        return list(result.scalars().all())
