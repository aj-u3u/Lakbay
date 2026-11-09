from datetime import datetime

from sqlalchemy import case, distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.app_assessments.models import AppAssessment, RATING_FIELDS
from app.features.trips.models import Trip, TripMember


class AppAssessmentRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_accessible_trip(self, *, trip_id: int, user_id: int) -> Trip | None:
        result = await self.session.execute(
            select(Trip)
            .join(TripMember, TripMember.trip_id == Trip.trip_id)
            .where(
                Trip.trip_id == trip_id,
                TripMember.user_id == user_id,
                TripMember.status == "active",
            )
        )
        return result.scalar_one_or_none()

    async def get_mine(self, *, trip_id: int, user_id: int) -> AppAssessment | None:
        result = await self.session.execute(
            select(AppAssessment).where(
                AppAssessment.trip_id == trip_id,
                AppAssessment.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def add(self, assessment: AppAssessment) -> None:
        self.session.add(assessment)
        await self.session.flush()

    async def list_for_admin(
        self, *, window_start: datetime, limit: int, offset: int
    ) -> tuple[int, list[AppAssessment]]:
        where = AppAssessment.submitted_at >= window_start
        total = await self.session.scalar(
            select(func.count()).select_from(AppAssessment).where(where)
        )
        result = await self.session.execute(
            select(AppAssessment)
            .where(where)
            .order_by(AppAssessment.submitted_at.desc(), AppAssessment.app_assessment_id.desc())
            .offset(offset)
            .limit(limit)
        )
        return int(total or 0), list(result.scalars().all())

    async def summary_for_admin(self, *, window_start: datetime) -> dict:
        columns = [
            func.count(AppAssessment.app_assessment_id).label("response_count"),
            func.count(distinct(AppAssessment.user_id)).label("participant_count"),
        ]
        for field in RATING_FIELDS:
            rating_column = getattr(AppAssessment, field)
            columns.extend(
                [
                    func.count(rating_column).label(f"{field}_answered"),
                    func.avg(rating_column).label(f"{field}_average"),
                    *(
                        func.sum(case((rating_column == score, 1), else_=0)).label(
                            f"{field}_{score}"
                        )
                        for score in range(1, 6)
                    ),
                ]
            )
        result = await self.session.execute(
            select(*columns).where(AppAssessment.submitted_at >= window_start)
        )
        return dict(result.mappings().one())
