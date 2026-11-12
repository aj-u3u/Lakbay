from decimal import Decimal

from pydantic import BaseModel, Field, PositiveInt, model_validator

from app.features.routes.schemas import RouteSummaryResponse, TravelMode


class DestinationGroupsRequest(BaseModel):
    destination_ids: list[PositiveInt] = Field(min_length=2, max_length=10)
    travel_mode: TravelMode = "driving"
    group_size: int = Field(default=3, ge=2, le=4)
    max_groups: int = Field(default=3, ge=1, le=5)
    max_separation_km: float = Field(default=50, gt=0, le=200)
    max_route_minutes: int = Field(default=240, ge=1, le=1440)
    max_destination_cost: Decimal | None = Field(
        default=None, gt=0, max_digits=10, decimal_places=2
    )

    @model_validator(mode="after")
    def validate_ids(self) -> "DestinationGroupsRequest":
        if len(self.destination_ids) != len(set(self.destination_ids)):
            raise ValueError("destination_ids must not contain duplicate IDs")
        if self.group_size > len(self.destination_ids):
            raise ValueError("group_size cannot exceed the number of destinations")
        return self


class GroupScoreBreakdown(BaseModel):
    preference: float
    proximity: float
    route_efficiency: float
    district: float
    travel_mode_fit: float
    geo: float
    budget_fit: float
    popularity: float
    accessibility: float
    child_friendliness: float


class DestinationGroup(BaseModel):
    destination_ids: list[int]
    route_order: list[int]
    route: RouteSummaryResponse
    score: float
    scores: GroupScoreBreakdown
    estimated_destination_cost: Decimal
    route_distance_km: Decimal
    route_duration_minutes: int
    route_provider: str
    is_route_estimated: bool
    reasons: list[str]
    warnings: list[str]


class DestinationGroupsResponse(BaseModel):
    groups: list[DestinationGroup]
    candidates_considered: int
    warnings: list[str]
