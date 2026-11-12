from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, Field, PositiveInt, model_validator

TravelMode = Literal["driving", "walking", "public_transport"]
DistanceKm = Annotated[Decimal, Field(ge=0, max_digits=10, decimal_places=2)]
TrafficLevel = Literal["unknown", "light", "moderate", "heavy", "severe"]
# How the stop order was chosen: kept as requested, exact search over every
# order with OSRM travel times, OSRM Trip's heuristic, or nearest neighbor
# improved by 2-opt when OSRM is unavailable or the mode is estimated.
OrderMethod = Literal["requested", "exact", "osrm_trip", "nearest_neighbor_2opt"]


class RouteCoordinate(BaseModel):
    label: str | None = Field(default=None, max_length=255)
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


class RouteBaseRequest(BaseModel):
    destination_ids: list[PositiveInt] = Field(min_length=1, max_length=25)
    travel_mode: TravelMode = "driving"
    origin: RouteCoordinate | None = None
    return_to_origin: bool = False
    use_live_traffic: bool = False

    @model_validator(mode="after")
    def validate_unique_destination_ids(self) -> "RouteBaseRequest":
        if len(self.destination_ids) != len(set(self.destination_ids)):
            raise ValueError("destination_ids must not contain duplicate IDs")

        if self.return_to_origin and self.origin is None:
            raise ValueError("return_to_origin requires origin")

        return self


class RoutePreviewRequest(RouteBaseRequest):
    pass


class RouteOptimizeRequest(RouteBaseRequest):
    preserve_first_destination: bool = Field(
        default=True,
        description=(
            "When origin is absent, keep the first listed destination as the start. "
            "When origin is provided, it is always the fixed first stop and this "
            "setting has no effect."
        ),
    )


class RouteStop(BaseModel):
    order: int
    destination_id: int | None
    name: str
    lat: float
    lng: float
    is_origin: bool = False
    coordinate_basis: Literal["origin", "verified_arrival", "attraction"] = "attraction"


class RouteDirectionStep(BaseModel):
    order: int = Field(ge=1)
    instruction: str
    distance_meters: int = Field(ge=0)
    duration_seconds: int = Field(ge=0)


class RouteLeg(BaseModel):
    order: int
    from_destination_id: int | None
    to_destination_id: int | None
    from_name: str
    to_name: str
    distance_km: DistanceKm
    duration_minutes: int = Field(ge=0)
    is_estimated: bool
    normal_duration_minutes: int | None = Field(default=None, ge=0)
    traffic_delay_minutes: int | None = Field(default=None, ge=0)
    traffic_level: TrafficLevel | None = None
    steps: list[RouteDirectionStep] = Field(default_factory=list)


class RouteFerryCrossing(BaseModel):
    """A boat crossing inside a road route, such as a RoRo ferry to Samal."""

    name: str | None = None
    distance_km: DistanceKm
    duration_minutes: int = Field(ge=0)
    from_lat: float | None = None
    from_lng: float | None = None
    to_lat: float | None = None
    to_lng: float | None = None


class RouteTrafficSummary(BaseModel):
    provider: str
    live_duration_minutes: int = Field(ge=0)
    normal_duration_minutes: int = Field(ge=0)
    delay_minutes: int = Field(ge=0)
    traffic_level: TrafficLevel
    cache_hit: bool = False
    advisory: str


class RouteSummaryResponse(BaseModel):
    travel_mode: TravelMode
    route_provider: str
    is_estimated: bool
    order_method: OrderMethod = "requested"
    total_distance_km: DistanceKm
    total_duration_minutes: int = Field(ge=0)
    stops: list[RouteStop]
    legs: list[RouteLeg]
    polyline: str | None = None
    polyline_encoding: Literal["polyline5"] | None = None
    arrival_points_verified: bool = False
    warnings: list[str] = Field(default_factory=list)
    traffic: RouteTrafficSummary | None = None
    # Boat parts of the route. The total time includes the crossing but not
    # waiting at the pier.
    ferry_crossings: list[RouteFerryCrossing] = Field(default_factory=list)
