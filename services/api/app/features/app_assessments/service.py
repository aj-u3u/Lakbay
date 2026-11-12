from datetime import UTC, datetime, timedelta

from fastapi import status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.app_assessments.models import AppAssessment, RATING_FIELDS
from app.features.app_assessments.repository import AppAssessmentRepository
from app.features.app_assessments.schemas import (
    AdminAppAssessmentListResponse,
    AdminAppAssessmentResponse,
    AdminAppAssessmentSummaryResponse,
    AppAssessmentCreate,
    AppAssessmentResponse,
    MyAppAssessmentResponse,
    QuestionMetrics,
)
from app.features.users.models import User


class AppAssessmentService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.assessments = AppAssessmentRepository(session)

    async def get_mine(self, *, user: User, trip_id: int) -> MyAppAssessmentResponse:
        await self._require_trip(user=user, trip_id=trip_id)
        assessment = await self.assessments.get_mine(trip_id=trip_id, user_id=user.user_id)
        return MyAppAssessmentResponse(
            assessment=(
                AppAssessmentResponse.model_validate(assessment, from_attributes=True)
                if assessment is not None else None
            )
        )

    async def create(
        self, *, user: User, trip_id: int, data: AppAssessmentCreate
    ) -> AppAssessmentResponse:
        trip = await self._require_trip(user=user, trip_id=trip_id)
        if trip.status != "completed":
            raise LakbayAPIError(
                "App assessments can only be submitted for completed trips.",
                code="trip_not_completed",
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        if await self.assessments.get_mine(trip_id=trip_id, user_id=user.user_id):
            raise _duplicate_error()
        assessment = AppAssessment(
            trip_id=trip_id,
            user_id=user.user_id,
            question_version=1,
            **data.model_dump(),
        )
        try:
            await self.assessments.add(assessment)
            await self.session.commit()
        except IntegrityError as exc:
            await self.session.rollback()
            cause = str(exc.orig).lower()
            if (
                "uq_app_assessments_trip_user" in cause
                or "app_assessments.trip_id, app_assessments.user_id" in cause
            ):
                raise _duplicate_error() from exc
            raise LakbayAPIError(
                "The assessment could not be saved because the trip changed. Refresh and try again.",
                code="app_assessment_conflict",
                status_code=status.HTTP_409_CONFLICT,
            ) from exc
        await self.session.refresh(assessment)
        return AppAssessmentResponse.model_validate(assessment, from_attributes=True)

    async def list_for_admin(
        self, *, window_days: int, limit: int, offset: int
    ) -> AdminAppAssessmentListResponse:
        start = datetime.now(UTC) - timedelta(days=window_days)
        total, rows = await self.assessments.list_for_admin(
            window_start=start, limit=limit, offset=offset
        )
        return AdminAppAssessmentListResponse(
            total=total,
            items=[
                AdminAppAssessmentResponse.model_validate(row, from_attributes=True)
                for row in rows
            ],
        )

    async def summary_for_admin(
        self, *, window_days: int
    ) -> AdminAppAssessmentSummaryResponse:
        now = datetime.now(UTC)
        start = now - timedelta(days=window_days)
        aggregates = await self.assessments.summary_for_admin(window_start=start)
        response_count = int(aggregates["response_count"] or 0)
        questions = {}
        for field in RATING_FIELDS:
            answered = int(aggregates[f"{field}_answered"] or 0)
            average = aggregates[f"{field}_average"]
            questions[field] = QuestionMetrics(
                answered=answered,
                not_applicable=response_count - answered,
                average=round(float(average), 2) if average is not None else None,
                ratings={
                    score: int(aggregates[f"{field}_{score}"] or 0)
                    for score in range(1, 6)
                },
            )
        return AdminAppAssessmentSummaryResponse(
            window_start=start,
            generated_at=now,
            response_count=response_count,
            participant_count=int(aggregates["participant_count"] or 0),
            questions=questions,
        )

    async def _require_trip(self, *, user: User, trip_id: int):
        trip = await self.assessments.get_accessible_trip(
            trip_id=trip_id, user_id=user.user_id
        )
        if trip is None:
            raise LakbayAPIError(
                "Trip was not found.",
                code="trip_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )
        return trip


def _duplicate_error() -> LakbayAPIError:
    return LakbayAPIError(
        "You have already submitted an app assessment for this trip.",
        code="app_assessment_already_exists",
        status_code=status.HTTP_409_CONFLICT,
    )
