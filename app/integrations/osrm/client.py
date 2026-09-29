import httpx

from app.core.config import Settings, get_settings
from app.features.routes.schemas import RouteCoordinate, TravelMode
from app.integrations.osrm.errors import (
    OSRMClientError,
    OSRMConfigurationError,
    OSRMRouteNotFoundError,
)
from app.integrations.osrm.schemas import OSRMLeg, OSRMRouteResult


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
        body = await self._get_json(
            f"/route/v1/{profile}/{_coordinates_path(coordinates)}",
            params={"overview": "false", "steps": "false"},
        )

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
        source = "first" if preserve_first else "any"
        destination = "any"

        if not roundtrip and not preserve_first:
            # OSRM does not support roundtrip=false with source=any and
            # destination=any, so keep the first coordinate as the start.
            source = "first"

        body = await self._get_json(
            f"/trip/v1/{profile}/{_coordinates_path(coordinates)}",
            params={
                "overview": "false",
                "steps": "false",
                "roundtrip": str(roundtrip).lower(),
                "source": source,
                "destination": destination,
            },
        )

        return _parse_trip_response(body)

    async def _get_json(self, path: str, *, params: dict[str, str]) -> dict:
        if not self.settings.osrm_base_url:
            raise OSRMConfigurationError("OSRM_BASE_URL is not configured.")

        async with httpx.AsyncClient(
            base_url=self.settings.osrm_base_url.rstrip("/"),
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


def get_osrm_client() -> OSRMClient:
    return OSRMClient()


def _coordinates_path(coordinates: list[RouteCoordinate]) -> str:
    return ";".join(f"{item.lng:.6f},{item.lat:.6f}" for item in coordinates)


def _parse_route_response(body: dict) -> OSRMRouteResult:
    routes = body.get("routes") or []

    if not routes:
        raise OSRMRouteNotFoundError("OSRM did not return a route.")

    route = routes[0]

    return OSRMRouteResult(
        total_distance_meters=float(route.get("distance") or 0),
        total_duration_seconds=float(route.get("duration") or 0),
        legs=_parse_legs(route),
    )


def _parse_trip_response(body: dict) -> OSRMRouteResult:
    trips = body.get("trips") or []
    waypoints = body.get("waypoints") or []

    if not trips:
        raise OSRMRouteNotFoundError("OSRM did not return a trip.")

    ordered_indices = [
        input_index
        for input_index, waypoint in sorted(
            enumerate(waypoints),
            key=lambda item: item[1].get("waypoint_index", 0),
        )
    ]
    trip = trips[0]

    return OSRMRouteResult(
        total_distance_meters=float(trip.get("distance") or 0),
        total_duration_seconds=float(trip.get("duration") or 0),
        legs=_parse_legs(trip),
        stop_order=ordered_indices,
    )


def _parse_legs(route: dict) -> list[OSRMLeg]:
    return [
        OSRMLeg(
            distance_meters=float(leg.get("distance") or 0),
            duration_seconds=float(leg.get("duration") or 0),
        )
        for leg in route.get("legs") or []
    ]
