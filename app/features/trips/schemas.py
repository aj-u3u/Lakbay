from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, PositiveInt, model_validator

from app.features.routes.schemas import TravelMode

TripStatus = Literal["planned", "ongoing", "completed", "archived"]
TripMemberRole = Literal["owner", "organizer", "member"]
TripAssignableMemberRole = Literal["organizer", "member"]
TripMemberStatus = Literal["active", "removed"]
TripTaskStatus = Literal["pending", "ongoing", "completed"]
Money = Annotated[Decimal, Field(ge=0, max_digits=10, decimal_places=2)]
DistanceKm = Annotated[Decimal, Field(ge=0, max_digits=10, decimal_places=2)]


class TripItineraryActivityCreate(BaseModel):
    activity_order: PositiveInt
    time: str | None = Field(default=None, max_length=20)
    title: str = Field(min_length=1, max_length=255)
    description: str | None = None
    destination_id: int | None = Field(default=None, ge=1)
    accommodation_id: int | None = Field(default=None, ge=1)
    transportation_id: int | None = Field(default=None, ge=1)
    estimated_cost: Money = Decimal("0.00")
    notes: str | None = None


class TripItineraryDayCreate(BaseModel):
    day_number: PositiveInt
    title: str = Field(min_length=1, max_length=255)
    summary: str | None = None
    activities: list[TripItineraryActivityCreate] = Field(
        default_factory=list,
        max_length=30,
    )

    @model_validator(mode="after")
    def validate_unique_activity_orders(self) -> "TripItineraryDayCreate":
        activity_orders = [activity.activity_order for activity in self.activities]

        if len(activity_orders) != len(set(activity_orders)):
            raise ValueError("activity_order values must be unique per itinerary day")

        return self


class TripCreate(BaseModel):
    title: str = Field(min_length=2, max_length=255)
    description: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    traveler_count: int = Field(default=1, ge=1, le=100)
    total_budget: Money = Decimal("0.00")
    estimated_total_cost: Money = Decimal("0.00")
    destination_ids: list[PositiveInt] = Field(min_length=1, max_length=25)
    notes: str | None = None
    itinerary_days: list[TripItineraryDayCreate] = Field(
        default_factory=list,
        max_length=30,
    )

    @model_validator(mode="after")
    def validate_trip_create(self) -> "TripCreate":
        _validate_date_range(self.start_date, self.end_date)
        _require_unique_ids("destination_ids", self.destination_ids)
        _require_unique_day_numbers(self.itinerary_days)

        return self


class TripFromAIOptionCreate(BaseModel):
    generation_run_id: PositiveInt
    option_number: PositiveInt
    start_date: date | None = None
    end_date: date | None = None
    notes: str | None = None

    @model_validator(mode="after")
    def validate_dates(self) -> "TripFromAIOptionCreate":
        _validate_date_range(self.start_date, self.end_date)
        return self


class TripUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=255)
    description: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    traveler_count: int | None = Field(default=None, ge=1, le=100)
    total_budget: Money | None = None
    estimated_total_cost: Money | None = None
    status: TripStatus | None = None
    notes: str | None = None

    @model_validator(mode="after")
    def validate_update_date_range(self) -> "TripUpdate":
        if self.start_date is not None and self.end_date is not None:
            _validate_date_range(self.start_date, self.end_date)

        return self


class TripRouteCreate(BaseModel):
    travel_mode: TravelMode
    route_provider: str = Field(min_length=1, max_length=100)
    is_estimated: bool
    total_distance_km: DistanceKm
    total_duration_minutes: int = Field(ge=0)
    stops: list["TripRouteStop"] = Field(min_length=1, max_length=30)
    legs: list["TripRouteLeg"] = Field(default_factory=list, max_length=30)
    warnings: list[str] = Field(default_factory=list, max_length=20)

    @model_validator(mode="after")
    def validate_route_summary(self) -> "TripRouteCreate":
        _require_sequential_orders("stops", [stop.order for stop in self.stops])
        _require_sequential_orders("legs", [leg.order for leg in self.legs])

        expected_leg_count = max(len(self.stops) - 1, 0)

        if len(self.legs) != expected_leg_count:
            raise ValueError("legs must describe each segment between route stops")

        return self


class TripRouteStop(BaseModel):
    order: PositiveInt
    destination_id: int | None = Field(default=None, ge=1)
    name: str = Field(min_length=1, max_length=255)
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    is_origin: bool = False

    @model_validator(mode="after")
    def validate_origin_destination(self) -> "TripRouteStop":
        if self.is_origin and self.destination_id is not None:
            raise ValueError("origin stops must not include a destination_id")

        if not self.is_origin and self.destination_id is None:
            raise ValueError("non-origin stops must include a destination_id")

        return self


class TripRouteLeg(BaseModel):
    order: PositiveInt
    from_destination_id: int | None = Field(default=None, ge=1)
    to_destination_id: int | None = Field(default=None, ge=1)
    from_name: str = Field(min_length=1, max_length=255)
    to_name: str = Field(min_length=1, max_length=255)
    distance_km: DistanceKm
    duration_minutes: int = Field(ge=0)
    is_estimated: bool


class TripMemberCreate(BaseModel):
    email: EmailStr
    role: TripAssignableMemberRole = "member"


class TripMemberUpdate(BaseModel):
    role: TripAssignableMemberRole


class TripTaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = None
    assigned_trip_member_id: int | None = Field(default=None, ge=1)
    due_date: date | None = None
    status: TripTaskStatus = "pending"


class TripTaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    assigned_trip_member_id: int | None = Field(default=None, ge=1)
    due_date: date | None = None
    status: TripTaskStatus | None = None


class TripDestinationResponse(BaseModel):
    trip_destination_id: int
    destination_id: int
    name: str
    stop_order: int


class TripItineraryActivityResponse(BaseModel):
    trip_itinerary_activity_id: int
    destination_id: int | None
    accommodation_id: int | None
    transportation_id: int | None
    activity_order: int
    time: str | None
    title: str
    description: str | None
    estimated_cost: Decimal
    notes: str | None


class TripItineraryDayResponse(BaseModel):
    trip_itinerary_day_id: int
    day_number: int
    title: str
    summary: str | None
    activities: list[TripItineraryActivityResponse]


class TripRouteResponse(BaseModel):
    trip_route_id: int
    trip_id: int
    travel_mode: str
    route_provider: str
    is_estimated: bool
    total_distance_km: Decimal
    total_duration_minutes: int
    stops: list[TripRouteStop]
    legs: list[TripRouteLeg]
    warnings: list[str]
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TripMemberResponse(BaseModel):
    trip_member_id: int
    trip_id: int
    user_id: int
    full_name: str
    email: EmailStr
    role: TripMemberRole
    status: TripMemberStatus
    joined_at: datetime
    created_at: datetime
    updated_at: datetime


class TripTaskResponse(BaseModel):
    trip_task_id: int
    trip_id: int
    created_by_user_id: int
    assigned_trip_member_id: int | None
    title: str
    description: str | None
    status: TripTaskStatus
    due_date: date | None
    completed_at: datetime | None
    created_at: datetime
    updated_at: datetime


class TripListItemResponse(BaseModel):
    trip_id: int
    owner_user_id: int
    title: str
    description: str | None
    start_date: date | None
    end_date: date | None
    traveler_count: int
    total_budget: Decimal
    estimated_total_cost: Decimal
    status: str
    notes: str | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TripResponse(TripListItemResponse):
    destinations: list[TripDestinationResponse]
    itinerary_days: list[TripItineraryDayResponse]
    route: TripRouteResponse | None = None
    planning_snapshot: dict | None = None
    members: list[TripMemberResponse] = Field(default_factory=list)
    tasks: list[TripTaskResponse] = Field(default_factory=list)


def _validate_date_range(start_date: date | None, end_date: date | None) -> None:
    if start_date is not None and end_date is not None and end_date < start_date:
        raise ValueError("end_date must be on or after start_date")


def _require_unique_ids(field_name: str, values: list[int]) -> None:
    if len(values) != len(set(values)):
        raise ValueError(f"{field_name} must not contain duplicate IDs")


def _require_unique_day_numbers(days: list[TripItineraryDayCreate]) -> None:
    day_numbers = [day.day_number for day in days]

    if len(day_numbers) != len(set(day_numbers)):
        raise ValueError("day_number values must be unique")


def _require_sequential_orders(field_name: str, values: list[int]) -> None:
    if values != list(range(1, len(values) + 1)):
        raise ValueError(f"{field_name} order values must start at 1 and be sequential")
