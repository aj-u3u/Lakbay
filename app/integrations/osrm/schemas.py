from dataclasses import dataclass


@dataclass(frozen=True)
class OSRMLeg:
    distance_meters: float
    duration_seconds: float


@dataclass(frozen=True)
class OSRMRouteResult:
    total_distance_meters: float
    total_duration_seconds: float
    legs: list[OSRMLeg]
    stop_order: list[int] | None = None
