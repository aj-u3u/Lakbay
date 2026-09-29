from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.destinations.repository import DestinationRepository
from app.features.destinations.schemas import (
    DestinationCreate,
    DestinationListQuery,
    DestinationResponse,
    DestinationUpdate,
)


class DestinationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.destinations = DestinationRepository(session)

    async def list_destinations(
        self,
        filters: DestinationListQuery,
    ) -> list[DestinationResponse]:
        destinations = await self.destinations.list(filters)

        return [DestinationResponse.model_validate(item) for item in destinations]

    async def get_destination(
        self,
        destination_id: int,
        *,
        include_inactive: bool = False,
    ) -> DestinationResponse:
        destination = await self.destinations.get_by_id(
            destination_id,
            include_inactive=include_inactive,
        )

        if destination is None:
            raise LakbayAPIError(
                "Destination was not found.",
                code="destination_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return DestinationResponse.model_validate(destination)

    async def create_destination(
        self,
        data: DestinationCreate,
    ) -> DestinationResponse:
        destination = await self.destinations.create(data)
        await self.session.commit()
        await self.session.refresh(destination)

        return DestinationResponse.model_validate(destination)

    async def update_destination(
        self,
        destination_id: int,
        data: DestinationUpdate,
    ) -> DestinationResponse:
        destination = await self.destinations.get_by_id(
            destination_id,
            include_inactive=True,
        )

        if destination is None:
            raise LakbayAPIError(
                "Destination was not found.",
                code="destination_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        values = data.model_dump(exclude_unset=True)

        if not values:
            raise LakbayAPIError(
                "At least one destination field must be provided.",
                code="empty_destination_update",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        updated_destination = await self.destinations.update(destination, values)
        await self.session.commit()
        await self.session.refresh(updated_destination)

        return DestinationResponse.model_validate(updated_destination)

    async def deactivate_destination(self, destination_id: int) -> DestinationResponse:
        destination = await self.destinations.get_by_id(
            destination_id,
            include_inactive=True,
        )

        if destination is None:
            raise LakbayAPIError(
                "Destination was not found.",
                code="destination_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        deactivated_destination = await self.destinations.deactivate(destination)
        await self.session.commit()
        await self.session.refresh(deactivated_destination)

        return DestinationResponse.model_validate(deactivated_destination)
