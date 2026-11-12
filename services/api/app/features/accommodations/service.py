from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.accommodations.repository import AccommodationRepository
from app.features.accommodations.schemas import (
    AccommodationCreate,
    AccommodationResponse,
    AccommodationUpdate,
)
from app.features.destinations.repository import DestinationRepository


class AccommodationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.accommodations = AccommodationRepository(session)
        self.destinations = DestinationRepository(session)

    async def list_for_destination(
        self,
        destination_id: int,
        *,
        include_unavailable: bool = False,
    ) -> list[AccommodationResponse]:
        await self._require_destination(destination_id)
        accommodations = await self.accommodations.list_by_destination(
            destination_id,
            include_unavailable=include_unavailable,
        )

        return [
            AccommodationResponse.model_validate(item) for item in accommodations
        ]

    async def create_accommodation(
        self,
        destination_id: int,
        data: AccommodationCreate,
    ) -> AccommodationResponse:
        await self._require_destination(destination_id)
        accommodation = await self.accommodations.create(
            destination_id=destination_id,
            data=data,
        )
        await self.session.commit()
        await self.session.refresh(accommodation)

        return AccommodationResponse.model_validate(accommodation)

    async def update_accommodation(
        self,
        accommodation_id: int,
        data: AccommodationUpdate,
    ) -> AccommodationResponse:
        accommodation = await self.accommodations.get_by_id(accommodation_id)

        if accommodation is None:
            raise LakbayAPIError(
                "Accommodation was not found.",
                code="accommodation_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        values = data.model_dump(exclude_unset=True)

        if not values:
            raise LakbayAPIError(
                "At least one accommodation field must be provided.",
                code="empty_accommodation_update",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        updated_accommodation = await self.accommodations.update(
            accommodation,
            values,
        )
        await self.session.commit()
        await self.session.refresh(updated_accommodation)

        return AccommodationResponse.model_validate(updated_accommodation)

    async def mark_accommodation_unavailable(
        self,
        accommodation_id: int,
    ) -> AccommodationResponse:
        accommodation = await self.accommodations.get_by_id(accommodation_id)

        if accommodation is None:
            raise LakbayAPIError(
                "Accommodation was not found.",
                code="accommodation_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        unavailable_accommodation = await self.accommodations.mark_unavailable(
            accommodation,
        )
        await self.session.commit()
        await self.session.refresh(unavailable_accommodation)

        return AccommodationResponse.model_validate(unavailable_accommodation)

    async def _require_destination(self, destination_id: int) -> None:
        destination = await self.destinations.get_by_id(destination_id)

        if destination is None:
            raise LakbayAPIError(
                "Destination was not found.",
                code="destination_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )
