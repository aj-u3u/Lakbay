from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.destinations.models import Destination


class GeoAnalyticsRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_active_by_ids(self, destination_ids: list[int]) -> list[Destination]:
        result = await self.session.execute(
            select(Destination).where(
                Destination.destination_id.in_(destination_ids),
                Destination.is_active.is_(True),
            )
        )
        return list(result.scalars().all())
