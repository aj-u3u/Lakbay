from math import isfinite

import httpx

from app.core.config import Settings, get_settings
from app.features.routes.schemas import RouteCoordinate, TravelMode
from app.integrations.osrm.errors import (
    OSRMClientError,
    OSRMConfigurationError,
    OSRMRouteNotFoundError,
)
from app.integrations.osrm.schemas import OSRMLeg, OSRMRouteResult, OSRMStep


MAX_PREVIEW_WAYPOINT_SNAP_METERS = 250.0


class OSRMClient:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    async def preview_route(
        self,
        *,
        travel_mode: TravelMode,
        coordinates: list[RouteCoordinate],
    ) -> OSRMRouteResult:
        profile = self._profile_for_mode(travel_mode)
        base_url = self._base_url_for_mode(travel_mode)
        body = await self._get_json(
            f"/route/v1/{profile}/{_coordinates_path(coordinates)}",
            params={"overview": "simplified", "steps": "true", "geometries": "polyline"},
            base_url=base_url,
        )

        _require_near_route_waypoints(body, len(coordinates))

        return _parse_route_response(body)

    async def optimize_route(
        self,
        *,
        travel_mode: TravelMode,
        coordinates: list[RouteCoordinate],
        roundtrip: bool,
        preserve_first: bool,
    ) -> OSRMRouteResult:
        profile = self._profile_for_mode(travel_mode)
        base_url = self._base_url_for_mode(travel_mode)
        source = "first" if preserve_first else "any"
        destination = "any" if roundtrip else "last"

        if not roundtrip:
            # OSRM Trip only supports an open route with a fixed first and
            # last coordinate. The interior stops can still be reordered.
            source = "first"

        body = await self._get_json(
            f"/trip/v1/{profile}/{_coordinates_path(coordinates)}",
            params={
                "overview": "simplified",
                "steps": "true",
                "geometries": "polyline",
                "roundtrip": str(roundtrip).lower(),
                "source": source,
                "destination": destination,
            },
            base_url=base_url,
        )

        return _parse_trip_response(body, expected_count=len(coordinates))

    async def _get_json(
        self, path: str, *, params: dict[str, str], base_url: str
    ) -> dict:
        async with httpx.AsyncClient(
            base_url=base_url.rstrip("/"),
            timeout=self.settings.osrm_request_timeout_seconds,
        ) as client:
            try:
                response = await client.get(path, params=params)
            except httpx.RequestError as exc:
                raise OSRMClientError("OSRM request failed.") from exc

        if response.status_code >= 500:
            raise OSRMClientError(
                "OSRM service returned a server error.",
                status_code=response.status_code,
            )

        try:
            body = response.json()
        except ValueError as exc:
            raise OSRMClientError("OSRM response was not valid JSON.") from exc

        provider_code = body.get("code")

        if response.status_code >= 400 or provider_code != "Ok":
            message = body.get("message") or "OSRM could not calculate a route."

            if provider_code in {"NoRoute", "NoTrips", "NoSegment", "NoTable"}:
                raise OSRMRouteNotFoundError(
                    message,
                    status_code=response.status_code,
                    provider_code=provider_code,
                )

            raise OSRMClientError(
                message,
                status_code=response.status_code,
                provider_code=provider_code,
            )

        return body

    def _profile_for_mode(self, travel_mode: TravelMode) -> str:
        if travel_mode == "driving":
            return self.settings.osrm_profile_driving

        if travel_mode == "walking":
            return self.settings.osrm_profile_walking

        raise OSRMConfigurationError("OSRM does not support public_transport mode.")

    def _base_url_for_mode(self, travel_mode: TravelMode) -> str:
        if travel_mode == "driving":
            base_url = self.settings.osrm_base_url
            setting_name = "OSRM_BASE_URL"
        elif travel_mode == "walking":
            base_url = self.settings.osrm_walking_base_url
            setting_name = "OSRM_WALKING_BASE_URL"
        else:
            raise OSRMConfigurationError("OSRM does not support public_transport mode.")
        if not base_url:
            raise OSRMConfigurationError(f"{setting_name} is not configured.")
        if (
            travel_mode == "walking"
            and self.settings.osrm_base_url
            and base_url.rstrip("/") == self.settings.osrm_base_url.rstrip("/")
        ):
            raise OSRMConfigurationError(
                "OSRM_WALKING_BASE_URL must use a separate foot-profile service."
            )
        return base_url


def get_osrm_client() -> OSRMClient:
    return OSRMClient()


def _coordinates_path(coordinates: list[RouteCoordinate]) -> str:
    return ";".join(f"{item.lng:.6f},{item.lat:.6f}" for item in coordinates)


def _require_near_route_waypoints(body: dict, expected_count: int) -> None:
    """A distant OSRM snap is not evidence of a route to the requested point."""
    waypoints = body.get("waypoints")
    if not isinstance(waypoints, list) or len(waypoints) != expected_count:
        raise OSRMRouteNotFoundError("OSRM did not confirm every route waypoint.")
    for waypoint in waypoints:
        if not isinstance(waypoint, dict):
            raise OSRMRouteNotFoundError("OSRM returned an invalid route waypoint.")
        distance = waypoint.get("distance")
        if (
            not isinstance(distance, (int, float)) or isinstance(distance, bool)
            or not isfinite(distance) or distance < 0
            or distance > MAX_PREVIEW_WAYPOINT_SNAP_METERS
        ):
            raise OSRMRouteNotFoundError(
                "OSRM snapped a route waypoint too far from the requested point."
            )


def _parse_route_response(body: dict) -> OSRMRouteResult:
    routes = body.get("routes") or []

    if not routes:
        raise OSRMRouteNotFoundError("OSRM did not return a route.")

    route = routes[0]

    return OSRMRouteResult(
        total_distance_meters=float(route.get("distance") or 0),
        total_duration_seconds=float(route.get("duration") or 0),
        legs=_parse_legs(route),
        polyline=route.get("geometry"),
    )


def _parse_trip_response(body: dict, expected_count: int) -> OSRMRouteResult:
    trips = body.get("trips")
    waypoints = body.get("waypoints")

    if not isinstance(trips, list) or not trips:
        raise OSRMRouteNotFoundError("OSRM did not return a trip.")
    if len(trips) != 1 or not isinstance(trips[0], dict):
        raise OSRMClientError("OSRM did not return exactly one trip.")
    if not isinstance(waypoints, list) or len(waypoints) != expected_count:
        raise OSRMClientError("OSRM returned an unexpected number of trip waypoints.")

    waypoint_indices = []
    for waypoint in waypoints:
        if not isinstance(waypoint, dict):
            raise OSRMClientError("OSRM returned an invalid trip waypoint.")
        waypoint_index = waypoint.get("waypoint_index")
        trips_index = waypoint.get("trips_index")
        if (
            not isinstance(waypoint_index, int) or isinstance(waypoint_index, bool)
            or not isinstance(trips_index, int) or isinstance(trips_index, bool)
        ):
            raise OSRMClientError("OSRM returned invalid trip waypoint indices.")
        if trips_index != 0:
            raise OSRMClientError("OSRM assigned a waypoint to another trip.")
        waypoint_indices.append(waypoint_index)

    if set(waypoint_indices) != set(range(expected_count)):
        raise OSRMClientError("OSRM returned an invalid trip stop order.")

    ordered_indices = [
        input_index
        for input_index, waypoint in sorted(
            enumerate(waypoints),
            key=lambda item: item[1]["waypoint_index"],
        )
    ]
    trip = trips[0]

    return OSRMRouteResult(
        total_distance_meters=float(trip.get("distance") or 0),
        total_duration_seconds=float(trip.get("duration") or 0),
        legs=_parse_legs(trip),
        stop_order=ordered_indices,
        polyline=trip.get("geometry"),
    )


def _parse_legs(route: dict) -> list[OSRMLeg]:
    return [
        OSRMLeg(
            distance_meters=float(leg.get("distance") or 0),
            duration_seconds=float(leg.get("duration") or 0),
            steps=[
                OSRMStep(
                    distance_meters=float(step.get("distance") or 0),
                    duration_seconds=float(step.get("duration") or 0),
                    maneuver_type=(step.get("maneuver") or {}).get("type") or "continue",
                    modifier=(step.get("maneuver") or {}).get("modifier"),
                    road_name=step.get("name") or None,
                    exit_number=(step.get("maneuver") or {}).get("exit"),
                )
                for step in leg.get("steps") or []
            ],
        )
        for leg in route.get("legs") or []
    ]
