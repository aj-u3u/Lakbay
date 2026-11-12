from datetime import UTC, datetime

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.expenses.service import ExpenseService
from app.features.reports.pdf import build_trip_report_pdf
from app.features.reports.repository import ReportRepository
from app.features.reports.schemas import (
    TripReportActivity,
    TripReportDestination,
    TripReportInfo,
    TripReportItineraryDay,
    TripReportMember,
    TripReportSummaryResponse,
    TripReportTask,
)
from app.features.trips.models import Trip, TripItineraryDay, TripMember
from app.features.trips.schemas import TripRouteResponse
from app.features.users.models import User


class ReportService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.reports = ReportRepository(session)

    async def get_summary(self, *, user: User, trip_id: int) -> TripReportSummaryResponse:
        trip = await self._require_accessible_trip(user=user, trip_id=trip_id)
        expenses = await ExpenseService(self.session).get_summary(user=user, trip_id=trip_id)

        return TripReportSummaryResponse(
            generated_at=datetime.now(UTC),
            trip=_trip_info(trip),
            destinations=[
                TripReportDestination(
                    destination_id=item.destination_id,
                    name=item.destination.name,
                    stop_order=item.stop_order,
                )
                for item in sorted(trip.destinations, key=lambda item: item.stop_order)
            ],
            itinerary_days=[
                _itinerary_day_response(day)
                for day in sorted(trip.itinerary_days, key=lambda day: day.day_number)
            ],
            route=(
                TripRouteResponse.model_validate(trip.route)
                if trip.route is not None
                else None
            ),
            expenses=expenses,
            members=[
                _member_response(member)
                for member in sorted(_active_members(trip), key=lambda member: member.trip_member_id)
            ],
            tasks=[
                TripReportTask(
                    title=task.title,
                    status=task.status,
                    due_date=task.due_date,
                )
                for task in sorted(trip.tasks, key=lambda task: task.trip_task_id)
            ],
        )

    async def build_pdf(self, *, user: User, trip_id: int) -> bytes:
        summary = await self.get_summary(user=user, trip_id=trip_id)
        return build_trip_report_pdf(summary)

    async def _require_accessible_trip(self, *, user: User, trip_id: int) -> Trip:
        trip = await self.reports.get_accessible_trip(
            user_id=user.user_id,
            trip_id=trip_id,
        )

        if trip is None:
            raise LakbayAPIError(
                "Trip was not found.",
                code="trip_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return trip


def _trip_info(trip: Trip) -> TripReportInfo:
    return TripReportInfo(
        trip_id=trip.trip_id,
        title=trip.title,
        description=trip.description,
        start_date=trip.start_date,
        end_date=trip.end_date,
        traveler_count=trip.traveler_count,
        total_budget=trip.total_budget,
        estimated_total_cost=trip.estimated_total_cost,
        status=trip.status,
        notes=trip.notes,
    )


def _itinerary_day_response(day: TripItineraryDay) -> TripReportItineraryDay:
    return TripReportItineraryDay(
        day_number=day.day_number,
        title=day.title,
        summary=day.summary,
        activities=[
            TripReportActivity(
                activity_order=activity.activity_order,
                time=activity.time,
                title=activity.title,
                description=activity.description,
                estimated_cost=activity.estimated_cost,
                notes=activity.notes,
            )
            for activity in sorted(day.activities, key=lambda activity: activity.activity_order)
        ],
    )


def _member_response(member: TripMember) -> TripReportMember:
    return TripReportMember(
        trip_member_id=member.trip_member_id,
        user_id=member.user_id,
        full_name=member.user.full_name,
        email=member.user.email,
        role=member.role,
        status=member.status,
    )


def _active_members(trip: Trip) -> list[TripMember]:
    return [member for member in trip.members if member.status == "active"]
