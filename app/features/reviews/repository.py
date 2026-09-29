from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.reviews.models import TripReview
from app.features.trips.models import Trip, TripDestination, TripMember


class ReviewRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_trip_with_members(self, *, trip_id: int) -> Trip | None:
        result = await self.session.execute(
            select(Trip)
            .where(Trip.trip_id == trip_id)
            .options(
                selectinload(Trip.members).selectinload(TripMember.user),
                selectinload(Trip.destinations).selectinload(TripDestination.destination),
            )
        )

        return result.scalar_one_or_none()

    async def list_reviews(
        self,
        *,
        trip_id: int,
        destination_id: int | None,
        limit: int,
        offset: int,
    ) -> list[TripReview]:
        statement = (
            select(TripReview)
            .where(
                TripReview.trip_id == trip_id,
                TripReview.status == "active",
            )
            .options(*_review_options())
            .order_by(TripReview.created_at.desc(), TripReview.trip_review_id.desc())
            .offset(offset)
            .limit(limit)
        )

        if destination_id is not None:
            statement = statement.where(TripReview.destination_id == destination_id)

        result = await self.session.execute(statement)

        return list(result.scalars().all())

    async def list_active_reviews_for_summary(self, *, trip_id: int) -> list[TripReview]:
        result = await self.session.execute(
            select(TripReview)
            .where(
                TripReview.trip_id == trip_id,
                TripReview.destination_id.is_(None),
                TripReview.status == "active",
            )
            .options(*_review_options())
            .order_by(TripReview.trip_review_id.asc())
        )

        return list(result.scalars().all())

    async def get_review(
        self,
        *,
        trip_id: int,
        review_id: int,
        include_deleted: bool = False,
    ) -> TripReview | None:
        statement = (
            select(TripReview)
            .where(
                TripReview.trip_id == trip_id,
                TripReview.trip_review_id == review_id,
            )
            .options(*_review_options())
        )

        if not include_deleted:
            statement = statement.where(TripReview.status == "active")

        result = await self.session.execute(statement)

        return result.scalar_one_or_none()

    async def get_existing_active_review(
        self,
        *,
        trip_id: int,
        user_id: int,
        destination_id: int | None,
    ) -> TripReview | None:
        statement = select(TripReview).where(
            TripReview.trip_id == trip_id,
            TripReview.user_id == user_id,
            TripReview.status == "active",
        )

        if destination_id is None:
            statement = statement.where(TripReview.destination_id.is_(None))
        else:
            statement = statement.where(TripReview.destination_id == destination_id)

        result = await self.session.execute(statement)

        return result.scalar_one_or_none()

    async def add_review(self, review: TripReview) -> TripReview:
        self.session.add(review)
        await self.session.flush()

        return review


def _review_options():
    return (
        selectinload(TripReview.member).selectinload(TripMember.user),
        selectinload(TripReview.destination),
    )
