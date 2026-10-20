from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.trips.models import (
    Trip,
    TripDestination,
    TripItineraryDay,
    TripMember,
)


class ReportRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_accessible_trip(self, *, user_id: int, trip_id: int) -> Trip | None:
        result = await self.session.execute(
            select(Trip)
            .where(Trip.trip_id == trip_id, _trip_access_filter(user_id))
            .options(
                selectinload(Trip.destinations).selectinload(TripDestination.destination),
                selectinload(Trip.itinerary_days).selectinload(TripItineraryDay.activities),
                selectinload(Trip.route),
                selectinload(Trip.members).selectinload(TripMember.user),
                selectinload(Trip.tasks),
            )
        )

        return result.scalar_one_or_none()


def _trip_access_filter(user_id: int):
    return or_(
        Trip.owner_user_id == user_id,
        Trip.members.any(
            and_(
                TripMember.user_id == user_id,
                TripMember.status == "active",
            )
        ),
    )
