from dataclasses import dataclass
from decimal import Decimal
from math import asin, cos, radians, sin, sqrt
from typing import Literal

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import LakbayAPIError
from app.features.destinations.models import Destination
from app.features.routes.repository import RouteRepository
from app.features.routes.schemas import (
    RouteCoordinate,
    RouteDirectionStep,
    RouteFerryCrossing,
    RouteLeg,
    RouteOptimizeRequest,
    RoutePreviewRequest,
    RouteStop,
    RouteSummaryResponse,
    RouteTrafficSummary,
    TrafficLevel,
    TravelMode,
)
from app.integrations.google_routes.client import GoogleRoutesClient
from app.integrations.google_routes.errors import GoogleRoutesClientError
from app.integrations.google_routes.schemas import GoogleRouteLeg, GoogleRouteResult
from app.integrations.osrm.client import OSRMClient
from app.integrations.osrm.errors import OSRMClientError
from app.integrations.osrm.schemas import (
    OSRMFerryCrossing,
    OSRMLeg,
    OSRMRouteResult,
    OSRMStep,
)

EARTH_RADIUS_KM = 6371.0
ZERO_DISTANCE = Decimal("0.00")
FALLBACK_SPEED_KMH = {
    "driving": Decimal("40"),
    "walking": Decimal("5"),
    "public_transport": Decimal("30"),
}


@dataclass(frozen=True)
class RoutePlanStop:
    destination_id: int | None
    name: str
    lat: float
    lng: float
    is_origin: bool = False
    coordinate_basis: Literal["origin", "verified_arrival", "attraction"] = "attraction"

    @property
    def coordinate(self) -> RouteCoordinate:
        return RouteCoordinate(label=self.name, lat=self.lat, lng=self.lng)


class RouteService:
    def __init__(
        self,
        session: AsyncSession,
        osrm_client: OSRMClient,
        google_routes_client: GoogleRoutesClient | None = None,
    ) -> None:
        self.routes = RouteRepository(session)
        self.osrm_client = osrm_client
        self.google_routes_client = google_routes_client

    async def preview_route(
        self,
        data: RoutePreviewRequest,
    ) -> RouteSummaryResponse:
        stops = await self._build_stops(data)
        route_stops = _append_return_stop(stops, data.return_to_origin)

        if data.travel_mode == "public_transport":
            return _estimated_response(
                travel_mode=data.travel_mode,
                stops=route_stops,
                route_provider="stored_transportation_estimate",
                warnings=[
                    "Public transport routing is estimated in Phase 6. Use "
                    "Phase 2 transportation rates for fare choices.",
                ],
            )

        if len(route_stops) <= 1:
            return _empty_route_response(
                travel_mode=data.travel_mode,
                stops=route_stops,
                route_provider="none",
                is_estimated=False,
            )

        traffic_response, live_traffic_warning = await self._try_live_traffic(
            data, route_stops,
        )
        if traffic_response is not None:
            return traffic_response

        warnings = [live_traffic_warning] if live_traffic_warning else []

        try:
            osrm_result = await self.osrm_client.preview_route(
                travel_mode=data.travel_mode,
                coordinates=[stop.coordinate for stop in route_stops],
            )

            return _osrm_response(
                travel_mode=data.travel_mode,
                stops=route_stops,
                osrm_result=osrm_result,
                warnings=warnings,
            )
        except (OSRMClientError, ValueError):
            warnings.append("OSRM was unavailable, so Haversine estimates were used.")

            return _estimated_response(
                travel_mode=data.travel_mode,
                stops=route_stops,
                route_provider="haversine",
                warnings=warnings,
            )

    async def optimize_route(
        self,
        data: RouteOptimizeRequest,
    ) -> RouteSummaryResponse:
        stops = await self._build_stops(data)

        if data.travel_mode == "public_transport":
            ordered_stops = _nearest_neighbor_order(
                stops,
                preserve_first=data.origin is not None or data.preserve_first_destination,
            )
            route_stops = _append_return_stop(ordered_stops, data.return_to_origin)

            return _estimated_response(
                travel_mode=data.travel_mode,
                stops=route_stops,
                route_provider="stored_transportation_estimate",
                warnings=[
                    "Public transport route order is estimated from destination "
                    "coordinates in Phase 6.",
                ],
            )

        if len(stops) <= 1:
            return _empty_route_response(
                travel_mode=data.travel_mode,
                stops=stops,
                route_provider="none",
                is_estimated=False,
            )

        preserve_first = data.origin is not None or data.preserve_first_destination
        order_warning = (
            "OSRM Trip returns a suggested route order; it is not "
            "guaranteed to be mathematically optimal."
        )

        try:
            osrm_result = await self.osrm_client.optimize_route(
                travel_mode=data.travel_mode,
                coordinates=[stop.coordinate for stop in stops],
                roundtrip=data.return_to_origin,
                preserve_first=preserve_first,
            )
            ordered_stops = _apply_stop_order(
                stops, osrm_result.stop_order, preserve_first=preserve_first,
            )
            route_stops = _append_return_stop(ordered_stops, data.return_to_origin)
            osrm_response = _osrm_response(
                travel_mode=data.travel_mode,
                stops=route_stops,
                osrm_result=osrm_result,
                warnings=[order_warning],
            )
        except (OSRMClientError, ValueError):
            ordered_stops = _nearest_neighbor_order(
                stops,
                preserve_first=preserve_first,
            )
            route_stops = _append_return_stop(ordered_stops, data.return_to_origin)

            traffic_response, live_traffic_warning = await self._try_live_traffic(
                data,
                route_stops,
                success_warnings=[
                    "OSRM optimization was unavailable, so Haversine "
                    "nearest-neighbor ordering was used before adding "
                    "live traffic ETA.",
                ],
            )
            if traffic_response is not None:
                return traffic_response

            warnings = [live_traffic_warning] if live_traffic_warning else []
            warnings.append(
                "OSRM optimization was unavailable, so a Haversine "
                "nearest-neighbor estimate was used."
            )

            return _estimated_response(
                travel_mode=data.travel_mode,
                stops=route_stops,
                route_provider="haversine",
                warnings=warnings,
            )

        traffic_response, live_traffic_warning = await self._try_live_traffic(
            data,
            route_stops,
            success_warnings=[
                order_warning,
                "OSRM was used to suggest destination order; "
                "Google Routes added live traffic ETA.",
            ],
        )
        if traffic_response is not None:
            return traffic_response
        if live_traffic_warning:
            osrm_response.warnings.insert(0, live_traffic_warning)
        return osrm_response

    async def _try_live_traffic(
        self,
        data: RoutePreviewRequest | RouteOptimizeRequest,
        stops: list[RoutePlanStop],
        *,
        success_warnings: list[str] | None = None,
    ) -> tuple[RouteSummaryResponse | None, str | None]:
        if not _can_use_live_traffic(data, stops, self.google_routes_client):
            return None, None

        try:
            google_result = await self.google_routes_client.compute_route(
                travel_mode=data.travel_mode,
                coordinates=[stop.coordinate for stop in stops],
            )
            return _google_routes_response(
                travel_mode=data.travel_mode,
                stops=stops,
                google_result=google_result,
                warnings=success_warnings,
            ), None
        except (GoogleRoutesClientError, ValueError) as exc:
            return None, _traffic_warning(exc)

    async def _build_stops(
        self,
        data: RoutePreviewRequest | RouteOptimizeRequest,
    ) -> list[RoutePlanStop]:
        settings = get_settings()

        if len(data.destination_ids) > settings.route_max_destinations:
            raise LakbayAPIError(
                "Too many destinations were provided for one route request.",
                code="route_destination_limit_exceeded",
                status_code=status.HTTP_400_BAD_REQUEST,
                details={
                    "max_destinations": settings.route_max_destinations,
                    "destination_count": len(data.destination_ids),
                },
            )

        destinations = await self.routes.list_active_destinations_by_ids(
            list(data.destination_ids),
        )
        destination_by_id = {
            destination.destination_id: destination for destination in destinations
        }
        missing_ids = [
            destination_id
            for destination_id in data.destination_ids
            if destination_id not in destination_by_id
        ]

        if missing_ids:
            raise LakbayAPIError(
                "One or more destinations were not found or are inactive.",
                code="destination_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
                details={"destination_ids": missing_ids},
            )

        ordered_destinations = [
            destination_by_id[destination_id] for destination_id in data.destination_ids
        ]
        stops = []

        if data.origin is not None:
            stops.append(
                RoutePlanStop(
                    destination_id=None,
                    name=data.origin.label or "Origin",
                    lat=data.origin.lat,
                    lng=data.origin.lng,
                    is_origin=True,
                    coordinate_basis="origin",
                )
            )

        for destination in ordered_destinations:
            stops.append(_destination_to_stop(destination))

        self._require_valid_coordinates(stops)

        return stops

    def _require_valid_coordinates(self, stops: list[RoutePlanStop]) -> None:
        invalid_stops = [
            stop.destination_id
            for stop in stops
            if stop.lat is None
            or stop.lng is None
            or not (-90 <= stop.lat <= 90)
            or not (-180 <= stop.lng <= 180)
        ]

        if invalid_stops:
            raise LakbayAPIError(
                "One or more route stops have invalid coordinates.",
                code="invalid_route_coordinates",
                status_code=status.HTTP_400_BAD_REQUEST,
                details={"destination_ids": invalid_stops},
            )


def _destination_to_stop(destination: Destination) -> RoutePlanStop:
    has_verified_arrival = bool(
        destination.route_ready
        and destination.arrival_lat is not None
        and destination.arrival_lng is not None
        and destination.arrival_source_url
        and destination.arrival_verified_at
    )
    return RoutePlanStop(
        destination_id=destination.destination_id,
        name=destination.name,
        lat=destination.arrival_lat if has_verified_arrival else destination.lat,
        lng=destination.arrival_lng if has_verified_arrival else destination.lng,
        coordinate_basis="verified_arrival" if has_verified_arrival else "attraction",
    )


def _append_return_stop(
    stops: list[RoutePlanStop],
    return_to_origin: bool,
) -> list[RoutePlanStop]:
    if not return_to_origin or len(stops) <= 1:
        return stops

    return [*stops, stops[0]]


def _apply_stop_order(
    stops: list[RoutePlanStop],
    stop_order: list[int] | None,
    *,
    preserve_first: bool,
) -> list[RoutePlanStop]:
    if stop_order is None:
        raise ValueError("OSRM did not return an optimized stop order.")

    if sorted(stop_order) != list(range(len(stops))):
        raise ValueError("OSRM returned an invalid optimized stop order.")

    if preserve_first and stop_order[0] != 0:
        raise ValueError("OSRM moved the preserved first stop.")

    return [stops[index] for index in stop_order]


def _osrm_response(
    *,
    travel_mode: TravelMode,
    stops: list[RoutePlanStop],
    osrm_result: OSRMRouteResult,
    warnings: list[str] | None = None,
) -> RouteSummaryResponse:
    expected_leg_count = max(len(stops) - 1, 0)

    if len(osrm_result.legs) != expected_leg_count:
        raise ValueError("OSRM returned a leg count that does not match the stops.")

    verified = _arrival_points_verified(stops)
    legs = [
        _route_leg_from_osrm(
            order=index, start=start, end=end, leg=leg, show_steps=verified,
        )
        for index, (start, end, leg) in enumerate(
            zip(stops, stops[1:], osrm_result.legs),
            start=1,
        )
    ]
    ferries = [_ferry_crossing(item) for item in osrm_result.ferry_crossings]
    response_warnings = [
        *(warnings or []),
        *_arrival_warnings(stops),
        *(_ferry_warning(item) for item in ferries),
    ]

    return RouteSummaryResponse(
        travel_mode=travel_mode,
        route_provider="osrm",
        is_estimated=False,
        total_distance_km=_distance_km(osrm_result.total_distance_meters / 1000),
        total_duration_minutes=_duration_minutes(osrm_result.total_duration_seconds),
        stops=_response_stops(stops),
        legs=legs,
        polyline=osrm_result.polyline,
        polyline_encoding="polyline5" if osrm_result.polyline else None,
        arrival_points_verified=verified,
        warnings=response_warnings,
        ferry_crossings=ferries,
    )


def _ferry_crossing(crossing: OSRMFerryCrossing) -> RouteFerryCrossing:
    start = crossing.start or (None, None)
    end = crossing.end or (None, None)
    return RouteFerryCrossing(
        name=crossing.name,
        distance_km=_distance_km(crossing.distance_meters / 1000),
        duration_minutes=_duration_minutes(crossing.duration_seconds),
        from_lat=start[0],
        from_lng=start[1],
        to_lat=end[0],
        to_lng=end[1],
    )


def _ferry_warning(crossing: RouteFerryCrossing) -> str:
    name = f" ({crossing.name})" if crossing.name else ""
    return (
        f"This route includes a ferry crossing{name}, about "
        f"{crossing.duration_minutes} min on the boat. Check the schedule and "
        "fare before you travel; the travel time does not include waiting at "
        "the pier."
    )


def _google_routes_response(
    *,
    travel_mode: TravelMode,
    stops: list[RoutePlanStop],
    google_result: GoogleRouteResult,
    warnings: list[str] | None = None,
) -> RouteSummaryResponse:
    expected_leg_count = max(len(stops) - 1, 0)

    if len(google_result.legs) != expected_leg_count:
        raise ValueError("Google Routes returned a leg count that does not match the stops.")

    live_duration_minutes = _duration_minutes(google_result.total_duration_seconds)
    normal_duration_minutes = _duration_minutes(
        google_result.total_static_duration_seconds,
    )
    delay_minutes = max(live_duration_minutes - normal_duration_minutes, 0)
    traffic_level = _traffic_level(delay_minutes)
    verified = _arrival_points_verified(stops)
    legs = [
        _route_leg_from_google(
            order=index, start=start, end=end, leg=leg, show_steps=verified,
        )
        for index, (start, end, leg) in enumerate(
            zip(stops, stops[1:], google_result.legs),
            start=1,
        )
    ]
    response_warnings = [*(warnings or []), *_arrival_warnings(stops)]

    return RouteSummaryResponse(
        travel_mode=travel_mode,
        route_provider="google_routes",
        is_estimated=False,
        total_distance_km=_distance_km(google_result.total_distance_meters / 1000),
        total_duration_minutes=live_duration_minutes,
        stops=_response_stops(stops),
        legs=legs,
        polyline=google_result.polyline,
        polyline_encoding="polyline5" if google_result.polyline else None,
        arrival_points_verified=verified,
        warnings=response_warnings,
        traffic=RouteTrafficSummary(
            provider="google_routes",
            live_duration_minutes=live_duration_minutes,
            normal_duration_minutes=normal_duration_minutes,
            delay_minutes=delay_minutes,
            traffic_level=traffic_level,
            cache_hit=google_result.cache_hit,
            advisory=_traffic_advisory(traffic_level, delay_minutes),
        ),
    )


def _estimated_response(
    *,
    travel_mode: TravelMode,
    stops: list[RoutePlanStop],
    route_provider: str,
    warnings: list[str],
) -> RouteSummaryResponse:
    legs = _estimated_legs(travel_mode=travel_mode, stops=stops)
    total_distance = _distance_km(sum(leg.distance_km for leg in legs))
    total_duration = sum(leg.duration_minutes for leg in legs)

    return RouteSummaryResponse(
        travel_mode=travel_mode,
        route_provider=route_provider,
        is_estimated=True,
        total_distance_km=total_distance,
        total_duration_minutes=total_duration,
        stops=_response_stops(stops),
        legs=legs,
        warnings=[*warnings, *_arrival_warnings(stops)],
        arrival_points_verified=_arrival_points_verified(stops),
    )


def _empty_route_response(
    *,
    travel_mode: TravelMode,
    stops: list[RoutePlanStop],
    route_provider: str,
    is_estimated: bool,
) -> RouteSummaryResponse:
    return RouteSummaryResponse(
        travel_mode=travel_mode,
        route_provider=route_provider,
        is_estimated=is_estimated,
        total_distance_km=ZERO_DISTANCE,
        total_duration_minutes=0,
        stops=_response_stops(stops),
        legs=[],
        warnings=_arrival_warnings(stops),
        arrival_points_verified=_arrival_points_verified(stops),
    )


def _route_leg_from_osrm(
    *,
    order: int,
    start: RoutePlanStop,
    end: RoutePlanStop,
    leg: OSRMLeg,
    show_steps: bool,
) -> RouteLeg:
    return RouteLeg(
        order=order,
        from_destination_id=start.destination_id,
        to_destination_id=end.destination_id,
        from_name=start.name,
        to_name=end.name,
        distance_km=_distance_km(leg.distance_meters / 1000),
        duration_minutes=_duration_minutes(leg.duration_seconds),
        is_estimated=False,
        steps=[
            RouteDirectionStep(
                order=index,
                instruction=_osrm_instruction(step),
                distance_meters=round(step.distance_meters),
                duration_seconds=round(step.duration_seconds),
            )
            for index, step in enumerate(leg.steps, start=1)
        ] if show_steps else [],
    )


def _route_leg_from_google(
    *,
    order: int,
    start: RoutePlanStop,
    end: RoutePlanStop,
    leg: GoogleRouteLeg,
    show_steps: bool,
) -> RouteLeg:
    live_duration = _duration_minutes(leg.duration_seconds)
    normal_duration = _duration_minutes(leg.static_duration_seconds)
    delay_minutes = max(live_duration - normal_duration, 0)

    return RouteLeg(
        order=order,
        from_destination_id=start.destination_id,
        to_destination_id=end.destination_id,
        from_name=start.name,
        to_name=end.name,
        distance_km=_distance_km(leg.distance_meters / 1000),
        duration_minutes=live_duration,
        is_estimated=False,
        normal_duration_minutes=normal_duration,
        traffic_delay_minutes=delay_minutes,
        traffic_level=_traffic_level(delay_minutes),
        steps=[
            RouteDirectionStep(
                order=index,
                instruction=step.instruction,
                distance_meters=round(step.distance_meters),
                duration_seconds=round(step.duration_seconds),
            )
            for index, step in enumerate(leg.steps, start=1)
        ] if show_steps else [],
    )


def _estimated_legs(*, travel_mode: TravelMode, stops: list[RoutePlanStop]) -> list[RouteLeg]:
    legs = []

    for index, (start, end) in enumerate(zip(stops, stops[1:]), start=1):
        distance = _distance_km(_haversine_km(start, end))

        legs.append(
            RouteLeg(
                order=index,
                from_destination_id=start.destination_id,
                to_destination_id=end.destination_id,
                from_name=start.name,
                to_name=end.name,
                distance_km=distance,
                duration_minutes=_estimated_duration_minutes(
                    distance_km=distance,
                    travel_mode=travel_mode,
                ),
                is_estimated=True,
            )
        )

    return legs


def _response_stops(stops: list[RoutePlanStop]) -> list[RouteStop]:
    return [
        RouteStop(
            order=index,
            destination_id=stop.destination_id,
            name=stop.name,
            lat=stop.lat,
            lng=stop.lng,
            is_origin=stop.is_origin,
            coordinate_basis=stop.coordinate_basis,
        )
        for index, stop in enumerate(stops, start=1)
    ]


def _arrival_points_verified(stops: list[RoutePlanStop]) -> bool:
    destinations = [stop for stop in stops if not stop.is_origin]
    return bool(destinations) and all(
        stop.coordinate_basis == "verified_arrival" for stop in destinations
    )


def _arrival_warnings(stops: list[RoutePlanStop]) -> list[str]:
    if _arrival_points_verified(stops) or not any(not stop.is_origin for stop in stops):
        return []
    return [
        "Some stops use attraction coordinates. This route is a planning preview; "
        "confirm visitor entrances before using directions."
    ]


def _osrm_instruction(step: OSRMStep) -> str:
    road = f" onto {step.road_name}" if step.road_name else ""
    maneuver = step.maneuver_type.replace("_", " ").lower()
    modifier = (step.modifier or "").replace("uturn", "U-turn")
    if step.mode == "ferry":
        return f"Take the ferry{f' ({step.road_name})' if step.road_name else ''}"
    if maneuver == "depart":
        return f"Start{road}" if road else "Start the route"
    if maneuver == "arrive":
        return "Arrive at the destination"
    if maneuver in {"roundabout", "rotary"}:
        exit_text = f" and take exit {step.exit_number}" if step.exit_number else ""
        return f"Enter the roundabout{exit_text}{road}"
    if maneuver == "turn":
        return f"Turn {modifier}{road}".strip()
    if maneuver == "continue":
        return f"Continue{road}" if road else "Continue"
    if maneuver == "merge":
        return f"Merge {modifier}{road}".strip()
    return f"{maneuver.capitalize()} {modifier}{road}".strip()


def _nearest_neighbor_order(
    stops: list[RoutePlanStop],
    *,
    preserve_first: bool,
) -> list[RoutePlanStop]:
    if len(stops) <= 2:
        return stops

    if preserve_first:
        return _nearest_neighbor_from_start(stops, start_index=0)

    candidates = [
        _nearest_neighbor_from_start(stops, start_index=index)
        for index in range(len(stops))
    ]

    return min(candidates, key=_total_haversine_distance)


def _nearest_neighbor_from_start(
    stops: list[RoutePlanStop],
    *,
    start_index: int,
) -> list[RoutePlanStop]:
    remaining = stops.copy()
    ordered = [remaining.pop(start_index)]

    while remaining:
        current = ordered[-1]
        next_index = min(
            range(len(remaining)),
            key=lambda index: _haversine_km(current, remaining[index]),
        )
        ordered.append(remaining.pop(next_index))

    return ordered


def _total_haversine_distance(stops: list[RoutePlanStop]) -> float:
    return sum(_haversine_km(start, end) for start, end in zip(stops, stops[1:]))


def _haversine_km(start: RoutePlanStop, end: RoutePlanStop) -> float:
    lat_1 = radians(start.lat)
    lat_2 = radians(end.lat)
    delta_lat = radians(end.lat - start.lat)
    delta_lng = radians(end.lng - start.lng)

    value = (
        sin(delta_lat / 2) ** 2
        + cos(lat_1) * cos(lat_2) * sin(delta_lng / 2) ** 2
    )

    return 2 * EARTH_RADIUS_KM * asin(sqrt(value))


def _estimated_duration_minutes(
    *,
    distance_km: Decimal,
    travel_mode: TravelMode,
) -> int:
    if distance_km == ZERO_DISTANCE:
        return 0

    speed = FALLBACK_SPEED_KMH[travel_mode]

    return max(1, int(((distance_km / speed) * Decimal("60")).to_integral_value()))


def _distance_km(value) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"))


def _duration_minutes(seconds: float) -> int:
    if seconds <= 0:
        return 0

    return max(1, int((Decimal(str(seconds)) / Decimal("60")).to_integral_value()))


def _can_use_live_traffic(
    data: RoutePreviewRequest | RouteOptimizeRequest,
    stops: list[RoutePlanStop],
    google_routes_client: GoogleRoutesClient | None,
) -> bool:
    return (
        data.use_live_traffic
        and data.travel_mode == "driving"
        and len(stops) > 1
        and google_routes_client is not None
        and google_routes_client.is_configured
    )


def _traffic_warning(exc: GoogleRoutesClientError | ValueError) -> str:
    return f"Live traffic was unavailable ({exc}); route fallback was used."


def _traffic_level(delay_minutes: int) -> TrafficLevel:
    if delay_minutes <= 5:
        return "light"
    if delay_minutes <= 15:
        return "moderate"
    if delay_minutes <= 30:
        return "heavy"
    return "severe"


def _traffic_advisory(level: TrafficLevel, delay_minutes: int) -> str:
    if level == "severe":
        return (
            f"Severe traffic delay of about {delay_minutes} minutes. "
            "Leave earlier or choose another route."
        )
    if level == "heavy":
        return (
            f"Heavy traffic delay of about {delay_minutes} minutes. "
            "Consider adjusting departure time."
        )
    if level == "moderate":
        return f"Moderate traffic delay of about {delay_minutes} minutes. Add buffer time."
    return "Traffic is light on this route."
