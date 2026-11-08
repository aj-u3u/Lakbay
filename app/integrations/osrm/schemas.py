from dataclasses import dataclass, field


@dataclass(frozen=True)
class OSRMStep:
    distance_meters: float
    duration_seconds: float
    maneuver_type: str
    modifier: str | None = None
    road_name: str | None = None
    exit_number: int | None = None
    # OSRM travel mode for the step, such as "driving" or "ferry".
    mode: str = "driving"
    # Where the step starts, as (lat, lng), from the OSRM maneuver location.
    location: tuple[float, float] | None = None


@dataclass(frozen=True)
class OSRMLeg:
    distance_meters: float
    duration_seconds: float
    steps: list[OSRMStep] = field(default_factory=list)


@dataclass(frozen=True)
class OSRMFerryCrossing:
    """A boat part of a road route, between the boarding and landing points."""

    distance_meters: float
    duration_seconds: float
    name: str | None = None
    start: tuple[float, float] | None = None
    end: tuple[float, float] | None = None


@dataclass(frozen=True)
class OSRMRouteResult:
    total_distance_meters: float
    total_duration_seconds: float
    legs: list[OSRMLeg]
    stop_order: list[int] | None = None
    polyline: str | None = None
    ferry_crossings: list[OSRMFerryCrossing] = field(default_factory=list)
