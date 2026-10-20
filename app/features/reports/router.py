from typing import Annotated

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.reports.schemas import TripReportSummaryResponse
from app.features.reports.service import ReportService
from app.features.users.models import User


router = APIRouter(prefix="/trips/{trip_id}/reports", tags=["reports"])


@router.get(
    "/summary",
    response_model=TripReportSummaryResponse,
    summary="Get trip report summary",
    description=(
        "Protected endpoint that returns the trip, itinerary, route, budget, "
        "expense, and member data used for the downloadable trip report."
    ),
)
async def get_trip_report_summary(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripReportSummaryResponse:
    return await ReportService(session).get_summary(user=current_user, trip_id=trip_id)


@router.get(
    "/pdf",
    summary="Download trip report PDF",
    description=(
        "Protected endpoint that generates a downloadable PDF report for a trip. "
        "The report includes saved route, itinerary, budget, expense, and member "
        "contribution details."
    ),
)
async def download_trip_report_pdf(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Response:
    pdf_bytes = await ReportService(session).build_pdf(
        user=current_user,
        trip_id=trip_id,
    )
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": (
                f'attachment; filename="lakbay-trip-{trip_id}-report.pdf"'
            ),
        },
    )
