from dataclasses import dataclass, field


@dataclass(frozen=True)
class GoogleRouteStep:
    instruction: str
    distance_meters: float
    duration_seconds: float


@dataclass(frozen=True)
class GoogleRouteLeg:
    distance_meters: float
    duration_seconds: float
    static_duration_seconds: float
    steps: list[GoogleRouteStep] = field(default_factory=list)


@dataclass(frozen=True)
class GoogleRouteResult:
    total_distance_meters: float
    total_duration_seconds: float
    total_static_duration_seconds: float
    legs: list[GoogleRouteLeg]
    cache_hit: bool = False
    polyline: str | None = None

    @property
    def delay_seconds(self) -> float:
        return max(
            self.total_duration_seconds - self.total_static_duration_seconds,
            0,
        )
