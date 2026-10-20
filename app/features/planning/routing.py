"""Read-only route projection and explicit personal-vehicle fuel estimates."""

import re
import unicodedata
from decimal import Decimal, ROUND_HALF_UP
from math import isfinite

from app.core.exceptions import LakbayAPIError
from app.features.destinations.models import Destination
from app.features.planning.schemas import (
    PlanningFuelEstimate,
    PlanningRoutePreview,
    PlanningState,
    PlanningTransportOption,
)
from app.features.routes.schemas import (
    RouteCoordinate,
    RouteOptimizeRequest,
    RoutePreviewRequest,
    RouteSummaryResponse,
    TravelMode,
)
from app.features.routes.service import RouteService


_NON_ROAD_ACCESS = re.compile(
    r"\b(?:ferr(?:y|ies)|(?:speed)?boats?|bancas?|bangkas?|islands?|"
    r"(?:air|aero)?planes?|aircraft|flights?)\b",
    re.IGNORECASE,
)
_NON_ROAD_VEHICLE = re.compile(
    r"\b(?:ferr(?:y|ies)|(?:speed)?boats?|bancas?|bangkas?|ships?|(?:air|aero)?planes?|aircraft)\b",
    re.IGNORECASE,
)
_NON_ROAD_MODE = re.compile(r"\b(?:sea|air)\b", re.IGNORECASE)
_NON_ROAD_CONNECTION = re.compile(
    r"\b(?:(?:by|via)\s+(?:sea|air)|(?:sea|air)\s+(?:travel|transport|connection)|fly(?:ing)?)\b",
    re.IGNORECASE,
)
_ROAD_CATALOG_MODES = {
    "land", "road", "driving", "public_transport", "public transport",
    "bus", "van", "jeepney", "tricycle", "taxi", "rail", "train",
}


async def build_route_preview(
    state: PlanningState,
    destinations: list[Destination],
    transport_options: list[PlanningTransportOption],
    route_service: RouteService | None,
) -> tuple[PlanningRoutePreview, PlanningFuelEstimate]:
    """Route only a complete, unambiguous road selection; never modify state."""
    preferences = state.route_preferences
    route = PlanningRoutePreview(
        status="not_requested",
        order_strategy=(
            "optimize" if preferences is not None and preferences.optimize_order
            else "preserve_order"
        ),
    )
    if preferences is None:
        return route, _fuel_estimate(state, route)

    missing = []
    review = []
    if state.origin is None or state.origin.lat is None or state.origin.lng is None:
        missing.append("origin.coordinates")
    if not state.destination_ids:
        missing.append("destination_ids")
    if state.return_to_origin is None:
        missing.append("return_to_origin")
    if not state.selected_transport_option_ids:
        missing.append("selected_transport_option_ids")

    destination_by_id = {item.destination_id: item for item in destinations}
    unavailable = [
        item for item in state.destination_ids
        if item not in destination_by_id or not destination_by_id[item].is_active
    ]
    if unavailable:
        review.append("destination_availability")
        route.warnings.append(
            "The route needs every selected destination to remain active; "
            "unavailable destinations were not silently removed."
        )
    invalid_coordinates = [
        item.destination_id for item in destinations
        if item.destination_id in state.destination_ids and not _valid_coordinates(item)
    ]
    if invalid_coordinates:
        review.append("destination.coordinates")
        route.warnings.append("One or more selected destinations have unusable route coordinates.")

    options_by_id = {item.option_id: item for item in transport_options}
    invalid_transport = [
        item for item in state.selected_transport_option_ids if item not in options_by_id
    ]
    if invalid_transport:
        review.append("transport_selection")
        route.warnings.append("Review unavailable transportation choices before requesting a route.")
    selected_options = [
        options_by_id[item] for item in state.selected_transport_option_ids
        if item in options_by_id
    ]
    mode = _travel_mode(selected_options)
    route.travel_mode = mode
    if selected_options and mode is None:
        review.append("transport_connections")
        route.warnings.append(
            "This transportation selection contains mixed, non-road, or unknown modes; "
            "its connections must be reviewed before a road route can be shown."
        )

    non_road_destinations = [
        item for item in destinations
        if item.destination_id in state.destination_ids and _has_non_road_access_hint(item)
    ]
    if non_road_destinations:
        review.append("non_road_connections")
        route.warnings.append(
            "Catalog access notes mention an island, boat, ferry, sea, or air connection. "
            "A road route would not establish access or connection costs, even with "
            "traveler confirmation."
        )

    route.missing_information = list(dict.fromkeys([*missing, *review]))
    if review or missing:
        route.status = "needs_review" if review else "needs_details"
        return route, _fuel_estimate(state, route)
    if route_service is None:
        route.status = "needs_review"
        route.missing_information.append("routing_service")
        route.warnings.append("Routing is unavailable; travel choices and budget estimates are retained.")
        return route, _fuel_estimate(state, route)

    request_values = {
        "destination_ids": list(state.destination_ids),
        "travel_mode": mode,
        "origin": RouteCoordinate(
            label=state.origin.label,
            lat=state.origin.lat,
            lng=state.origin.lng,
        ),
        "return_to_origin": state.return_to_origin,
        "use_live_traffic": False,
    }
    try:
        if preferences.optimize_order:
            route.summary = await route_service.optimize_route(
                RouteOptimizeRequest(**request_values, preserve_first_destination=True),
            )
        else:
            route.summary = await route_service.preview_route(RoutePreviewRequest(**request_values))
    except LakbayAPIError as exc:
        route.status = "needs_review"
        route.missing_information.append(exc.code)
        route.warnings.append(exc.message)
        return route, _fuel_estimate(state, route)

    if not _summary_covers_journey(state, route.summary):
        route.status = "needs_review"
        route.summary = None
        route.missing_information.append("route_stop_coverage")
        route.warnings.append(
            "The returned route did not preserve the origin, selected stops, or return preference; "
            "review the route instead of pricing an incomplete or changed journey."
        )
        return route, _fuel_estimate(state, route)

    route.status = "calculated"
    route.warnings.extend(route.summary.warnings)
    route.warnings.append(
        "Distance and duration are planning estimates; a route result does not verify "
        "road access, schedules, ferry connections, or current traffic."
    )
    if route.summary.is_estimated or mode == "public_transport":
        route.warnings.append(
            "Estimated geometry does not confirm road distance or public-transport service; "
            "fares and connections still require separate review."
        )
    if mode == "driving" and not preferences.road_access_confirmed:
        route.status = "needs_review"
        route.missing_information.append("road_access_confirmation")
        route.warnings.append("Confirm that the full journey is accessible by road before estimating fuel.")
    fuel = _fuel_estimate(state, route)
    if fuel.included_in is not None:
        route.warnings.append(
            "Fuel is displayed for reference within the whole-trip transportation allowance; "
            "do not add it to that allowance a second time."
        )
    return route, fuel


def _travel_mode(options: list[PlanningTransportOption]) -> TravelMode | None:
    if len(options) == 1 and options[0].option_id == "mode:personal_vehicle":
        return "driving"
    if len(options) == 1 and options[0].option_id == "mode:walking":
        return "walking"
    if options and all(
        item.kind == "catalog_transport"
        and _canonical(item.transport_mode) in _ROAD_CATALOG_MODES
        and not _NON_ROAD_VEHICLE.search(item.vehicle_type)
        for item in options
    ):
        return "public_transport"
    return None


def _summary_covers_journey(state: PlanningState, summary: RouteSummaryResponse) -> bool:
    stops = summary.stops
    expected_count = len(state.destination_ids) + 1 + int(state.return_to_origin)
    if len(stops) != expected_count or len(summary.legs) != expected_count - 1:
        return False
    origin = state.origin
    first = stops[0]
    if not (
        first.is_origin and first.destination_id is None
        and first.lat == origin.lat and first.lng == origin.lng
    ):
        return False
    if state.return_to_origin:
        last = stops[-1]
        if not (
            last.is_origin and last.destination_id is None
            and last.lat == origin.lat and last.lng == origin.lng
        ):
            return False
    destination_stops = stops[1:-1] if state.return_to_origin else stops[1:]
    actual_ids = [stop.destination_id for stop in destination_stops]
    if any(stop.is_origin or stop.destination_id is None for stop in destination_stops):
        return False
    if state.route_preferences.optimize_order:
        return sorted(actual_ids) == sorted(state.destination_ids)
    return actual_ids == state.destination_ids


def _canonical(value: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def _valid_coordinates(destination: Destination) -> bool:
    if destination.lat is None or destination.lng is None:
        return False
    return (
        isfinite(destination.lat) and isfinite(destination.lng)
        and -90 <= destination.lat <= 90 and -180 <= destination.lng <= 180
    )


def _has_non_road_access_hint(destination: Destination) -> bool:
    # Mode tags can be terse; prose needs transport context so "fresh air" or
    # "air-conditioned bus" does not disable an otherwise supported road trip.
    return bool(_NON_ROAD_MODE.search(destination.transport_accessibility or "")) or any(
        _NON_ROAD_ACCESS.search(value or "") or _NON_ROAD_CONNECTION.search(value or "")
        for value in (
            destination.transport_accessibility,
            destination.how_to_get_there,
            destination.travel_notes,
        )
    )


def _fuel_estimate(state: PlanningState, route: PlanningRoutePreview) -> PlanningFuelEstimate:
    assumptions = state.fuel_assumptions
    fuel = PlanningFuelEstimate(status="not_requested")
    if assumptions is None:
        if (
            state.route_preferences is not None
            and state.selected_transport_option_ids == ["mode:personal_vehicle"]
        ):
            fuel.status = "needs_details"
            fuel.missing_information.append("fuel_assumptions")
        return fuel
    fuel.vehicle_count = assumptions.vehicle_count
    if state.selected_transport_option_ids != ["mode:personal_vehicle"]:
        fuel.status = "unavailable"
        fuel.missing_information.append("sole_personal_vehicle_selection")
        return fuel
    if state.route_preferences is None:
        fuel.status = "unavailable"
        fuel.missing_information.append("route_preferences")
        return fuel
    if route.summary is None:
        fuel.status = "unavailable"
        fuel.missing_information.append("complete_road_route")
        return fuel
    if not state.route_preferences.road_access_confirmed:
        fuel.status = "needs_details"
        fuel.missing_information.append("road_access_confirmation")
        return fuel
    if route.status != "calculated":
        fuel.status = "unavailable"
        fuel.missing_information.append("complete_road_route")
        return fuel

    summary = route.summary
    expected_leg_count = len(state.destination_ids) + (1 if state.return_to_origin else 0)
    leg_distance = sum((leg.distance_km for leg in summary.legs), Decimal("0.00"))
    # Individual legs and the provider total are rounded independently to cents.
    rounding_tolerance = Decimal("0.01") * (len(summary.legs) + 1)
    if (
        summary.route_provider != "osrm" or summary.is_estimated
        or summary.travel_mode != "driving" or any(leg.is_estimated for leg in summary.legs)
        or len(summary.legs) != expected_leg_count
        or abs(summary.total_distance_km - leg_distance) > rounding_tolerance
    ):
        fuel.status = "unavailable"
        fuel.missing_information.append("nonestimated_osrm_road_distance")
        return fuel

    distance = summary.total_distance_km
    unrounded_liters = (distance / assumptions.kilometers_per_liter) * assumptions.vehicle_count
    fuel.status = "calculated"
    fuel.distance_km = distance
    fuel.liters = unrounded_liters.quantize(Decimal("0.001"), rounding=ROUND_HALF_UP)
    fuel.amount = (unrounded_liters * assumptions.price_per_liter).quantize(
        Decimal("0.01"), rounding=ROUND_HALF_UP,
    )
    fuel.assumptions = [
        "Fuel efficiency and price per liter are traveler-provided estimates, not verified live rates.",
        "Road access is a traveler confirmation; the route provider does not verify ferry connections or vehicle-access restrictions.",
        "Fuel uses the returned road distance divided by kilometers per liter, multiplied by "
        "vehicle count and price per liter; traveler count does not multiply vehicle expenses.",
        "Parking, tolls, vehicle ferry charges, and other vehicle expenses are separate from fuel.",
    ]
    if any(item.category == "transportation" for item in state.cost_allowances):
        fuel.included_in = "allowance:transportation"
        fuel.assumptions.append("The whole-trip transportation allowance includes this fuel estimate.")
    return fuel
