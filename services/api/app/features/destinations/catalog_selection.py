"""Lookups and checks for the catalog places and rates a traveler selects.

AI itineraries, budget estimates, routes and saved trips accept selected
destination, accommodation and transportation IDs. They share these queries and
reject missing, inactive, or mismatched selections with the same errors.
"""

from fastapi import status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.accommodations.models import Accommodation
from app.features.destinations.models import Destination
from app.features.transportations.models import Transportation


class CatalogSelectionQueries:
    """Repository mixin that loads the selected catalog rows travelers may use."""

    session: AsyncSession

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


def require_all_destinations(
    requested_ids: list[int],
    destinations: list[Destination],
) -> None:
    found_ids = {destination.destination_id for destination in destinations}
    missing_ids = _missing_ids(requested_ids, found_ids)

    if missing_ids:
        raise LakbayAPIError(
            "One or more destinations were not found or are inactive.",
            code="destination_not_found",
            status_code=status.HTTP_404_NOT_FOUND,
            details={"destination_ids": missing_ids},
        )


def require_all_accommodations(
    requested_ids: list[int],
    accommodations: list[Accommodation],
) -> None:
    found_ids = {accommodation.accommodation_id for accommodation in accommodations}
    missing_ids = _missing_ids(requested_ids, found_ids)

    if missing_ids:
        raise LakbayAPIError(
            "One or more accommodations were not found or are unavailable.",
            code="accommodation_not_found",
            status_code=status.HTTP_404_NOT_FOUND,
            details={"accommodation_ids": missing_ids},
        )


def require_all_transportations(
    requested_ids: list[int],
    transportations: list[Transportation],
) -> None:
    found_ids = {transportation.transportation_id for transportation in transportations}
    missing_ids = _missing_ids(requested_ids, found_ids)

    if missing_ids:
        raise LakbayAPIError(
            "One or more transportation options were not found or are unavailable.",
            code="transportation_not_found",
            status_code=status.HTTP_404_NOT_FOUND,
            details={"transportation_ids": missing_ids},
        )


def require_rates_belong_to_destinations(
    *,
    accommodations: list[Accommodation],
    transportations: list[Transportation],
    destination_ids: set[int],
) -> None:
    mismatched_accommodation_ids = [
        accommodation.accommodation_id
        for accommodation in accommodations
        if accommodation.destination_id not in destination_ids
    ]

    if mismatched_accommodation_ids:
        raise LakbayAPIError(
            "Accommodation options must belong to the selected destinations.",
            code="accommodation_destination_mismatch",
            details={"accommodation_ids": mismatched_accommodation_ids},
        )

    mismatched_transportation_ids = [
        transportation.transportation_id
        for transportation in transportations
        if transportation.destination_id not in destination_ids
    ]

    if mismatched_transportation_ids:
        raise LakbayAPIError(
            "Transportation options must belong to the selected destinations.",
            code="transportation_destination_mismatch",
            details={"transportation_ids": mismatched_transportation_ids},
        )


def _missing_ids(requested_ids: list[int], found_ids: set[int]) -> list[int]:
    return [requested_id for requested_id in requested_ids if requested_id not in found_ids]
