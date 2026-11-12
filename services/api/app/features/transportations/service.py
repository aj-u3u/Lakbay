from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.destinations.repository import DestinationRepository
from app.features.transportations.repository import TransportationRepository
from app.features.transportations.schemas import (
    TransportationCreate,
    TransportationResponse,
    TransportationUpdate,
)


class TransportationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.transportations = TransportationRepository(session)
        self.destinations = DestinationRepository(session)

    async def list_for_destination(
        self,
        destination_id: int,
        *,
        include_unavailable: bool = False,
    ) -> list[TransportationResponse]:
        await self._require_destination(destination_id)
        transportations = await self.transportations.list_by_destination(
            destination_id,
            include_unavailable=include_unavailable,
        )

        return [
            TransportationResponse.model_validate(item) for item in transportations
        ]

    async def create_transportation(
        self,
        destination_id: int,
        data: TransportationCreate,
    ) -> TransportationResponse:
        await self._require_destination(destination_id)
        transportation = await self.transportations.create(
            destination_id=destination_id,
            data=data,
        )
        await self.session.commit()
        await self.session.refresh(transportation)

        return TransportationResponse.model_validate(transportation)

    async def update_transportation(
        self,
        transportation_id: int,
        data: TransportationUpdate,
    ) -> TransportationResponse:
        transportation = await self.transportations.get_by_id(transportation_id)

        if transportation is None:
            raise LakbayAPIError(
                "Transportation option was not found.",
                code="transportation_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        values = data.model_dump(exclude_unset=True)

        if not values:
            raise LakbayAPIError(
                "At least one transportation field must be provided.",
                code="empty_transportation_update",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        updated_transportation = await self.transportations.update(
            transportation,
            values,
        )
        await self.session.commit()
        await self.session.refresh(updated_transportation)

        return TransportationResponse.model_validate(updated_transportation)

    async def mark_transportation_unavailable(
        self,
        transportation_id: int,
    ) -> TransportationResponse:
        transportation = await self.transportations.get_by_id(transportation_id)

        if transportation is None:
            raise LakbayAPIError(
                "Transportation option was not found.",
                code="transportation_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        unavailable_transportation = await self.transportations.mark_unavailable(
            transportation,
        )
        await self.session.commit()
        await self.session.refresh(unavailable_transportation)

        return TransportationResponse.model_validate(unavailable_transportation)

    async def _require_destination(self, destination_id: int) -> None:
        destination = await self.destinations.get_by_id(destination_id)

        if destination is None:
            raise LakbayAPIError(
                "Destination was not found.",
                code="destination_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )
