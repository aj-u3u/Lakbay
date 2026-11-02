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

        if "route_ready" in values and values["route_ready"] is None:
            raise LakbayAPIError(
                "route_ready must be true or false.",
                code="invalid_route_ready",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        arrival_lat = values.get("arrival_lat", destination.arrival_lat)
        arrival_lng = values.get("arrival_lng", destination.arrival_lng)
        arrival_source_url = values.get("arrival_source_url", destination.arrival_source_url)
        arrival_verified_at = values.get("arrival_verified_at", destination.arrival_verified_at)
        route_ready = values.get("route_ready", destination.route_ready)
        if (arrival_lat is None) != (arrival_lng is None):
            raise LakbayAPIError(
                "Arrival latitude and longitude must be provided together.",
                code="invalid_arrival_point",
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        if route_ready and (
            arrival_lat is None
            or not arrival_source_url
            or arrival_verified_at is None
        ):
            raise LakbayAPIError(
                "A route-ready destination needs a sourced, verified arrival point.",
                code="arrival_point_unverified",
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        if route_ready and {"arrival_lat", "arrival_lng"}.intersection(values) and (
            "arrival_source_url" not in values or "arrival_verified_at" not in values
        ):
            raise LakbayAPIError(
                "Reconfirm the source and time when changing a route-ready arrival point.",
                code="arrival_point_reverification_required",
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
