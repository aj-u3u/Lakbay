from datetime import UTC, date, datetime, timedelta

import httpx

from app.core.config import Settings, get_settings
from app.features.routes.schemas import RouteCoordinate, TravelMode
from app.integrations.google_routes.errors import (
    GoogleRoutesClientError,
    GoogleRoutesConfigurationError,
    GoogleRoutesQuotaError,
    GoogleRoutesRouteNotFoundError,
)
from app.integrations.google_routes.schemas import GoogleRouteLeg, GoogleRouteResult

_CACHE: dict[str, tuple[datetime, GoogleRouteResult]] = {}
_REQUEST_COUNTS: dict[date, int] = {}


class GoogleRoutesClient:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    @property
    def is_configured(self) -> bool:
        return bool((self.settings.google_routes_api_key or "").strip())

    async def compute_route(
        self,
        *,
        travel_mode: TravelMode,
        coordinates: list[RouteCoordinate],
    ) -> GoogleRouteResult:
        if travel_mode != "driving":
            raise GoogleRoutesConfigurationError(
                "Google live traffic is only enabled for driving routes."
            )

        if len(coordinates) < 2:
            raise GoogleRoutesRouteNotFoundError("At least two route stops are required.")

        if not self.is_configured:
            raise GoogleRoutesConfigurationError("GOOGLE_ROUTES_API_KEY is not configured.")

        cache_key = self._cache_key(coordinates)
        cached = _cache_get(cache_key)
        if cached is not None:
            return GoogleRouteResult(
                total_distance_meters=cached.total_distance_meters,
                total_duration_seconds=cached.total_duration_seconds,
                total_static_duration_seconds=cached.total_static_duration_seconds,
                legs=cached.legs,
                cache_hit=True,
            )

        _require_daily_capacity(self.settings.google_routes_daily_request_limit)

        async with httpx.AsyncClient(
            base_url=self.settings.google_routes_base_url.rstrip("/"),
            timeout=self.settings.google_routes_request_timeout_seconds,
        ) as client:
            try:
                response = await client.post(
                    "/directions/v2:computeRoutes",
                    json=_request_body(coordinates),
                    headers=_request_headers(self.settings),
                )
            except httpx.RequestError as exc:
                raise GoogleRoutesClientError("Google Routes request failed.") from exc

        _record_request(self.settings.google_routes_daily_request_limit)
        result = _parse_response(response)
        _cache_set(cache_key, result, self.settings.google_routes_cache_ttl_seconds)

        return result

    def _cache_key(self, coordinates: list[RouteCoordinate]) -> str:
        points = ";".join(f"{item.lat:.5f},{item.lng:.5f}" for item in coordinates)
        return f"google-routes:v1:traffic-aware:{points}"


def get_google_routes_client() -> GoogleRoutesClient:
    return GoogleRoutesClient()


def _request_headers(settings: Settings) -> dict[str, str]:
    return {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": settings.google_routes_api_key or "",
        "X-Goog-FieldMask": ",".join(
            [
                "routes.distanceMeters",
                "routes.duration",
                "routes.staticDuration",
                "routes.legs.distanceMeters",
                "routes.legs.duration",
                "routes.legs.staticDuration",
            ]
        ),
    }


def _request_body(coordinates: list[RouteCoordinate]) -> dict:
    return {
        "origin": _waypoint(coordinates[0]),
        "destination": _waypoint(coordinates[-1]),
        "intermediates": [_waypoint(item) for item in coordinates[1:-1]],
        "travelMode": "DRIVE",
        "routingPreference": "TRAFFIC_AWARE_OPTIMAL",
        "computeAlternativeRoutes": False,
        "languageCode": "en-US",
        "units": "METRIC",
    }


def _waypoint(coordinate: RouteCoordinate) -> dict:
    return {
        "location": {
            "latLng": {
                "latitude": coordinate.lat,
                "longitude": coordinate.lng,
            }
        }
    }


def _parse_response(response: httpx.Response) -> GoogleRouteResult:
    try:
        body = response.json()
    except ValueError as exc:
        raise GoogleRoutesClientError("Google Routes response was not valid JSON.") from exc

    if response.status_code == 429:
        raise GoogleRoutesQuotaError(
            _error_message(body) or "Google Routes quota was exceeded.",
            status_code=response.status_code,
            provider_code=_error_status(body),
        )

    if response.status_code >= 500:
        raise GoogleRoutesClientError(
            "Google Routes service returned a server error.",
            status_code=response.status_code,
            provider_code=_error_status(body),
        )

    if response.status_code >= 400:
        raise GoogleRoutesClientError(
            _error_message(body) or "Google Routes rejected the request.",
            status_code=response.status_code,
            provider_code=_error_status(body),
        )

    routes = body.get("routes") or []
    if not routes:
        raise GoogleRoutesRouteNotFoundError("Google Routes did not return a route.")

    route = routes[0]
    duration_seconds = _duration_seconds(route.get("duration"))
    static_duration_seconds = _duration_seconds(route.get("staticDuration"))

    return GoogleRouteResult(
        total_distance_meters=float(route.get("distanceMeters") or 0),
        total_duration_seconds=duration_seconds,
        total_static_duration_seconds=(
            static_duration_seconds if static_duration_seconds > 0 else duration_seconds
        ),
        legs=[_parse_leg(leg) for leg in route.get("legs") or []],
    )


def _parse_leg(leg: dict) -> GoogleRouteLeg:
    duration_seconds = _duration_seconds(leg.get("duration"))
    static_duration_seconds = _duration_seconds(leg.get("staticDuration"))

    return GoogleRouteLeg(
        distance_meters=float(leg.get("distanceMeters") or 0),
        duration_seconds=duration_seconds,
        static_duration_seconds=(
            static_duration_seconds if static_duration_seconds > 0 else duration_seconds
        ),
    )


def _duration_seconds(value) -> float:
    if isinstance(value, str) and value.endswith("s"):
        return float(value[:-1] or 0)
    if isinstance(value, (int, float)):
        return float(value)
    return 0.0


def _error_message(body: dict) -> str | None:
    error = body.get("error") if isinstance(body, dict) else None
    if isinstance(error, dict):
        return error.get("message")
    return None


def _error_status(body: dict) -> str | None:
    error = body.get("error") if isinstance(body, dict) else None
    if isinstance(error, dict):
        return error.get("status")
    return None


def _cache_get(cache_key: str) -> GoogleRouteResult | None:
    cached = _CACHE.get(cache_key)
    if cached is None:
        return None

    expires_at, result = cached
    if datetime.now(UTC) >= expires_at:
        _CACHE.pop(cache_key, None)
        return None

    return result


def _cache_set(cache_key: str, result: GoogleRouteResult, ttl_seconds: int) -> None:
    if ttl_seconds <= 0:
        return

    _CACHE[cache_key] = (datetime.now(UTC) + timedelta(seconds=ttl_seconds), result)


def _require_daily_capacity(limit: int) -> None:
    if limit <= 0:
        return

    today = datetime.now(UTC).date()
    if _REQUEST_COUNTS.get(today, 0) >= limit:
        raise GoogleRoutesQuotaError("Daily Google Routes request limit was reached.")


def _record_request(limit: int) -> None:
    if limit <= 0:
        return

    today = datetime.now(UTC).date()
    _REQUEST_COUNTS[today] = _REQUEST_COUNTS.get(today, 0) + 1
