from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.accommodations.models import Accommodation
from app.features.accommodations.schemas import AccommodationCreate


class AccommodationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_by_destination(
        self,
        destination_id: int,
        *,
        include_unavailable: bool = False,
    ) -> list[Accommodation]:
        statement = select(Accommodation).where(
            Accommodation.destination_id == destination_id,
        )

        if not include_unavailable:
            statement = statement.where(Accommodation.is_available.is_(True))

        result = await self.session.execute(
            statement.order_by(Accommodation.price.asc(), Accommodation.name.asc()),
        )

        return list(result.scalars().all())

    async def get_by_id(
        self,
        accommodation_id: int,
        *,
        include_unavailable: bool = True,
    ) -> Accommodation | None:
        statement = select(Accommodation).where(
            Accommodation.accommodation_id == accommodation_id,
        )

        if not include_unavailable:
            statement = statement.where(Accommodation.is_available.is_(True))

        result = await self.session.execute(statement)

        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        destination_id: int,
        data: AccommodationCreate,
    ) -> Accommodation:
        accommodation = Accommodation(
            destination_id=destination_id,
            **data.model_dump(),
        )
        self.session.add(accommodation)
        await self.session.flush()

        return accommodation

    async def update(
        self,
        accommodation: Accommodation,
        values: dict,
    ) -> Accommodation:
        for field, value in values.items():
            setattr(accommodation, field, value)

        await self.session.flush()

        return accommodation

    async def mark_unavailable(self, accommodation: Accommodation) -> Accommodation:
        accommodation.is_available = False
        await self.session.flush()

        return accommodation
