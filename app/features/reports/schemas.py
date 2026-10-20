from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, EmailStr

from app.features.expenses.schemas import TripExpenseSummaryResponse
from app.features.trips.schemas import TripRouteResponse


class TripReportInfo(BaseModel):
    trip_id: int
    title: str
    description: str | None
    start_date: date | None
    end_date: date | None
    traveler_count: int
    total_budget: Decimal
    estimated_total_cost: Decimal
    status: str
    notes: str | None


class TripReportDestination(BaseModel):
    destination_id: int
    name: str
    stop_order: int


class TripReportActivity(BaseModel):
    activity_order: int
    time: str | None
    title: str
    description: str | None
    estimated_cost: Decimal
    notes: str | None


class TripReportItineraryDay(BaseModel):
    day_number: int
    title: str
    summary: str | None
    activities: list[TripReportActivity]


class TripReportMember(BaseModel):
    trip_member_id: int
    user_id: int
    full_name: str
    email: EmailStr
    role: str
    status: str


class TripReportTask(BaseModel):
    title: str
    status: str
    due_date: date | None


class TripReportSummaryResponse(BaseModel):
    generated_at: datetime
    trip: TripReportInfo
    destinations: list[TripReportDestination]
    itinerary_days: list[TripReportItineraryDay]
    route: TripRouteResponse | None
    expenses: TripExpenseSummaryResponse
    members: list[TripReportMember]
    tasks: list[TripReportTask]
