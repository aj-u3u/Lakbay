from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.transportations.models import Transportation
from app.features.transportations.schemas import TransportationCreate


class TransportationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_by_destination(
        self,
        destination_id: int,
        *,
        include_unavailable: bool = False,
    ) -> list[Transportation]:
        statement = select(Transportation).where(
            Transportation.destination_id == destination_id,
        )

        if not include_unavailable:
            statement = statement.where(Transportation.is_available.is_(True))

        result = await self.session.execute(
            statement.order_by(Transportation.price.asc(), Transportation.vehicle_type.asc()),
        )

        return list(result.scalars().all())

    async def get_by_id(
        self,
        transportation_id: int,
        *,
        include_unavailable: bool = True,
    ) -> Transportation | None:
        statement = select(Transportation).where(
            Transportation.transportation_id == transportation_id,
        )

        if not include_unavailable:
            statement = statement.where(Transportation.is_available.is_(True))

        result = await self.session.execute(statement)

        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        destination_id: int,
        data: TransportationCreate,
    ) -> Transportation:
        transportation = Transportation(
            destination_id=destination_id,
            **data.model_dump(),
        )
        self.session.add(transportation)
        await self.session.flush()

        return transportation

    async def update(
        self,
        transportation: Transportation,
        values: dict,
    ) -> Transportation:
        for field, value in values.items():
            setattr(transportation, field, value)

        await self.session.flush()

        return transportation

    async def mark_unavailable(self, transportation: Transportation) -> Transportation:
        transportation.is_available = False
        await self.session.flush()

        return transportation
