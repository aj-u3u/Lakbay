from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.ai.models import AIGenerationRun
from app.features.destinations.catalog_selection import CatalogSelectionQueries
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


class TripRepository(CatalogSelectionQueries):
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_owned_generation_run(
        self, *, user_id: int, generation_run_id: int,
    ) -> AIGenerationRun | None:
        result = await self.session.execute(
            select(AIGenerationRun).where(
                AIGenerationRun.ai_generation_run_id == generation_run_id,
                AIGenerationRun.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

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
