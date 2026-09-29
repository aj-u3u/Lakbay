from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.accommodations.models import Accommodation
from app.features.destinations.models import Destination
from app.features.transportations.models import Transportation
from app.features.trips.models import (
    Trip,
    TripDestination,
    TripItineraryDay,
    TripMember,
    TripRoute,
    TripTask,
)
from app.features.trips.schemas import TripRouteCreate
from app.features.users.models import User


class TripRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_accessible_trips(
        self,
        *,
        user_id: int,
        include_archived: bool,
        limit: int,
        offset: int,
    ) -> list[Trip]:
        statement = (
            select(Trip)
            .where(_trip_access_filter(user_id))
            .order_by(Trip.created_at.desc(), Trip.trip_id.desc())
            .offset(offset)
            .limit(limit)
        )

        if not include_archived:
            statement = statement.where(Trip.status != "archived")

        result = await self.session.execute(statement)

        return list(result.scalars().all())

    async def get_accessible_trip(
        self,
        *,
        user_id: int,
        trip_id: int,
    ) -> Trip | None:
        result = await self.session.execute(
            select(Trip)
            .where(Trip.trip_id == trip_id, _trip_access_filter(user_id))
            .options(*_trip_detail_options())
        )

        return result.scalar_one_or_none()

    async def create_trip(self, trip: Trip) -> Trip:
        self.session.add(trip)
        await self.session.flush()

        return trip

    async def get_user_by_email(self, email: str) -> User | None:
        result = await self.session.execute(
            select(User).where(User.email == email),
        )

        return result.scalar_one_or_none()

    async def list_trip_members(self, *, trip_id: int) -> list[TripMember]:
        result = await self.session.execute(
            select(TripMember)
            .where(
                TripMember.trip_id == trip_id,
                TripMember.status == "active",
            )
            .options(selectinload(TripMember.user))
            .order_by(TripMember.role.desc(), TripMember.trip_member_id.asc())
        )

        return list(result.scalars().all())

    async def get_trip_member(
        self,
        *,
        trip_id: int,
        trip_member_id: int,
    ) -> TripMember | None:
        result = await self.session.execute(
            select(TripMember)
            .where(
                TripMember.trip_id == trip_id,
                TripMember.trip_member_id == trip_member_id,
            )
            .options(selectinload(TripMember.user))
        )

        return result.scalar_one_or_none()

    async def get_trip_member_by_user_id(
        self,
        *,
        trip_id: int,
        user_id: int,
    ) -> TripMember | None:
        result = await self.session.execute(
            select(TripMember)
            .where(TripMember.trip_id == trip_id, TripMember.user_id == user_id)
            .options(selectinload(TripMember.user))
        )

        return result.scalar_one_or_none()

    async def add_trip_member(self, member: TripMember) -> TripMember:
        self.session.add(member)
        await self.session.flush()

        return member

    async def list_trip_tasks(
        self,
        *,
        trip_id: int,
        task_status: str | None,
        assigned_trip_member_id: int | None,
        limit: int,
        offset: int,
    ) -> list[TripTask]:
        statement = (
            select(TripTask)
            .where(TripTask.trip_id == trip_id)
            .order_by(TripTask.created_at.desc(), TripTask.trip_task_id.desc())
            .offset(offset)
            .limit(limit)
        )

        if task_status is not None:
            statement = statement.where(TripTask.status == task_status)

        if assigned_trip_member_id is not None:
            statement = statement.where(
                TripTask.assigned_trip_member_id == assigned_trip_member_id,
            )

        result = await self.session.execute(statement)

        return list(result.scalars().all())

    async def get_trip_task(
        self,
        *,
        trip_id: int,
        trip_task_id: int,
    ) -> TripTask | None:
        result = await self.session.execute(
            select(TripTask).where(
                TripTask.trip_id == trip_id,
                TripTask.trip_task_id == trip_task_id,
            )
        )

        return result.scalar_one_or_none()

    async def add_trip_task(self, task: TripTask) -> TripTask:
        self.session.add(task)
        await self.session.flush()

        return task

    async def delete_trip_task(self, task: TripTask) -> None:
        await self.session.delete(task)
        await self.session.flush()

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

    async def save_route(self, *, trip: Trip, data: TripRouteCreate) -> TripRoute:
        route_values = data.model_dump(mode="json")

        if trip.route is None:
            trip.route = TripRoute(**route_values)
        else:
            for field, value in route_values.items():
                setattr(trip.route, field, value)

        await self.session.flush()

        return trip.route


def _trip_detail_options():
    return (
        selectinload(Trip.destinations).selectinload(TripDestination.destination),
        selectinload(Trip.itinerary_days).selectinload(TripItineraryDay.activities),
        selectinload(Trip.route),
        selectinload(Trip.members).selectinload(TripMember.user),
        selectinload(Trip.tasks),
    )


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
