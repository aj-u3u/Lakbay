from dataclasses import dataclass
from decimal import Decimal
from math import asin, cos, radians, sin, sqrt

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import LakbayAPIError
from app.features.destinations.models import Destination
from app.features.routes.repository import RouteRepository
from app.features.routes.schemas import (
    RouteCoordinate,
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
from app.integrations.osrm.schemas import OSRMLeg, OSRMRouteResult

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

        live_traffic_warning = None
        if _can_use_live_traffic(data, route_stops, self.google_routes_client):
            try:
                google_result = await self.google_routes_client.compute_route(
                    travel_mode=data.travel_mode,
                    coordinates=[stop.coordinate for stop in route_stops],
                )
                return _google_routes_response(
                    travel_mode=data.travel_mode,
                    stops=route_stops,
                    google_result=google_result,
                )
            except GoogleRoutesClientError as exc:
                live_traffic_warning = _traffic_warning(exc)

        try:
            osrm_result = await self.osrm_client.preview_route(
                travel_mode=data.travel_mode,
                coordinates=[stop.coordinate for stop in route_stops],
            )

            return _osrm_response(
                travel_mode=data.travel_mode,
                stops=route_stops,
                osrm_result=osrm_result,
                warning=live_traffic_warning,
            )
        except (OSRMClientError, ValueError):
            warnings = ["OSRM was unavailable, so Haversine estimates were used."]
            if live_traffic_warning:
                warnings.insert(0, live_traffic_warning)

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

        try:
            osrm_result = await self.osrm_client.optimize_route(
                travel_mode=data.travel_mode,
                coordinates=[stop.coordinate for stop in stops],
                roundtrip=data.return_to_origin,
                preserve_first=preserve_first,
            )
            ordered_stops = _apply_stop_order(stops, osrm_result.stop_order)
            route_stops = _append_return_stop(ordered_stops, data.return_to_origin)

            live_traffic_warning = None
            if _can_use_live_traffic(data, route_stops, self.google_routes_client):
                try:
                    google_result = await self.google_routes_client.compute_route(
                        travel_mode=data.travel_mode,
                        coordinates=[stop.coordinate for stop in route_stops],
                    )
                    return _google_routes_response(
                        travel_mode=data.travel_mode,
                        stops=route_stops,
                        google_result=google_result,
                        warning=(
                            "OSRM was used to suggest destination order; "
                            "Google Routes added live traffic ETA."
                        ),
                    )
                except GoogleRoutesClientError as exc:
                    live_traffic_warning = _traffic_warning(exc)

            return _osrm_response(
                travel_mode=data.travel_mode,
                stops=route_stops,
                osrm_result=osrm_result,
                warning=(
                    live_traffic_warning
                    or "OSRM Trip returns a suggested route order; it is not "
                    "guaranteed to be mathematically optimal."
                ),
            )
        except (OSRMClientError, ValueError):
            ordered_stops = _nearest_neighbor_order(
                stops,
                preserve_first=preserve_first,
            )
            route_stops = _append_return_stop(ordered_stops, data.return_to_origin)

            live_traffic_warning = None
            if _can_use_live_traffic(data, route_stops, self.google_routes_client):
                try:
                    google_result = await self.google_routes_client.compute_route(
                        travel_mode=data.travel_mode,
                        coordinates=[stop.coordinate for stop in route_stops],
                    )
                    return _google_routes_response(
                        travel_mode=data.travel_mode,
                        stops=route_stops,
                        google_result=google_result,
                        warning=(
                            "OSRM optimization was unavailable, so Haversine "
                            "nearest-neighbor ordering was used before adding "
                            "live traffic ETA."
                        ),
                    )
                except GoogleRoutesClientError as exc:
                    live_traffic_warning = _traffic_warning(exc)

            warnings = [
                "OSRM optimization was unavailable, so a Haversine "
                "nearest-neighbor estimate was used.",
            ]
            if live_traffic_warning:
                warnings.insert(0, live_traffic_warning)

            return _estimated_response(
                travel_mode=data.travel_mode,
                stops=route_stops,
                route_provider="haversine",
                warnings=warnings,
            )

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
    return RoutePlanStop(
        destination_id=destination.destination_id,
        name=destination.name,
        lat=destination.lat,
        lng=destination.lng,
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
) -> list[RoutePlanStop]:
    if stop_order is None:
        raise ValueError("OSRM did not return an optimized stop order.")

    if sorted(stop_order) != list(range(len(stops))):
        raise ValueError("OSRM returned an invalid optimized stop order.")

    return [stops[index] for index in stop_order]


def _osrm_response(
    *,
    travel_mode: TravelMode,
    stops: list[RoutePlanStop],
    osrm_result: OSRMRouteResult,
    warning: str | None = None,
) -> RouteSummaryResponse:
    expected_leg_count = max(len(stops) - 1, 0)

    if len(osrm_result.legs) != expected_leg_count:
        raise ValueError("OSRM returned a leg count that does not match the stops.")

    legs = [
        _route_leg_from_osrm(order=index, start=start, end=end, leg=leg)
        for index, (start, end, leg) in enumerate(
            zip(stops, stops[1:], osrm_result.legs),
            start=1,
        )
    ]
    warnings = [warning] if warning else []

    return RouteSummaryResponse(
        travel_mode=travel_mode,
        route_provider="osrm",
        is_estimated=False,
        total_distance_km=_distance_km(osrm_result.total_distance_meters / 1000),
        total_duration_minutes=_duration_minutes(osrm_result.total_duration_seconds),
        stops=_response_stops(stops),
        legs=legs,
        warnings=warnings,
    )


def _google_routes_response(
    *,
    travel_mode: TravelMode,
    stops: list[RoutePlanStop],
    google_result: GoogleRouteResult,
    warning: str | None = None,
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
    legs = [
        _route_leg_from_google(order=index, start=start, end=end, leg=leg)
        for index, (start, end, leg) in enumerate(
            zip(stops, stops[1:], google_result.legs),
            start=1,
        )
    ]
    warnings = [warning] if warning else []

    return RouteSummaryResponse(
        travel_mode=travel_mode,
        route_provider="google_routes",
        is_estimated=False,
        total_distance_km=_distance_km(google_result.total_distance_meters / 1000),
        total_duration_minutes=live_duration_minutes,
        stops=_response_stops(stops),
        legs=legs,
        warnings=warnings,
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
        warnings=warnings,
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
        warnings=[],
    )


def _route_leg_from_osrm(
    *,
    order: int,
    start: RoutePlanStop,
    end: RoutePlanStop,
    leg: OSRMLeg,
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
    )


def _route_leg_from_google(
    *,
    order: int,
    start: RoutePlanStop,
    end: RoutePlanStop,
    leg: GoogleRouteLeg,
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
        )
        for index, stop in enumerate(stops, start=1)
    ]


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


def _traffic_warning(exc: GoogleRoutesClientError) -> str:
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
