import hashlib
import re
import unicodedata
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.features.destinations.models import Destination
from app.features.planning.costs import build_budget
from app.features.planning.feedback import evaluate_preview
from app.features.planning.repository import PlanningRepository
from app.features.planning.routing import build_route_preview
from app.features.planning.schemas import (
    PlanningActivityOption,
    PlanningAccommodationOption,
    PlanningDestination,
    PlanningFeedbackRequest,
    PlanningFeedbackResponse,
    PlanningNextAction,
    PlanningPreviewRequest,
    PlanningPreviewResponse,
    PlanningSelectionProblem,
    PlanningState,
    PlanningTransportOption,
)
from app.features.transportations.models import Transportation
from app.features.routes.service import RouteService


class PlanningService:
    def __init__(self, session: AsyncSession, route_service: RouteService | None = None) -> None:
        self.planning = PlanningRepository(session)
        self.route_service = route_service

    async def feedback(self, data: PlanningFeedbackRequest) -> PlanningFeedbackResponse:
        preview = await self.preview(data)
        active = await self.planning.list_active_destinations(data.state.destination_ids)
        by_id = {item.destination_id: item for item in active}
        destinations = [
            by_id[item] for item in data.state.destination_ids if item in by_id
        ]
        return evaluate_preview(
            preview, destinations,
            traveling_with_children=data.traveling_with_children,
        )

    async def preview(self, data: PlanningPreviewRequest) -> PlanningPreviewResponse:
        state = data.state
        destinations = await self.planning.list_active_destinations(state.destination_ids)
        destinations_by_id = {item.destination_id: item for item in destinations}
        # Preserve the traveler's chosen order, independent of database row order.
        destinations = [
            destinations_by_id[item] for item in state.destination_ids if item in destinations_by_id
        ]
        transportations = await self.planning.list_available_transportations(
            list(destinations_by_id),
        )
        transport_options = _transport_options(state, destinations_by_id, transportations)
        activity_options = _activity_options(state, destinations)
        accommodations = (
            await self.planning.list_available_accommodations(list(destinations_by_id))
            if state.night_count != 0 else []
        )
        accommodation_options = [
            PlanningAccommodationOption(
                accommodation_id=item.accommodation_id,
                destination_id=item.destination_id,
                name=item.name,
                room_type=item.room_type,
                capacity=item.capacity,
                listed_price=item.price,
                price_basis=item.charging_unit,
                selected=item.accommodation_id in state.selected_accommodation_ids,
            )
            for item in accommodations
        ]
        selection_problems = _selection_problems(
            state, destinations_by_id, transport_options, activity_options,
        )
        available_stays = {item.accommodation_id for item in accommodation_options}
        selection_problems.extend(
            PlanningSelectionProblem(
                field="selected_accommodation_ids",
                option_id=f"accommodation:{item}",
                code="accommodation_option_unavailable",
                message="This stay is unavailable for the selected destinations and overnight count.",
            )
            for item in state.selected_accommodation_ids if item not in available_stays
        )
        missing_inputs = _missing_inputs(state)
        whole_trip_budget = state.total_budget
        if state.budget_scope == "per_person":
            whole_trip_budget = (
                (state.total_budget * state.traveler_count).quantize(Decimal("0.01"))
                if state.total_budget is not None and state.traveler_count is not None
                else None
            )
        elif whole_trip_budget is not None:
            whole_trip_budget = whole_trip_budget.quantize(Decimal("0.01"))

        route, fuel = await build_route_preview(
            state, destinations, transport_options, self.route_service,
        )
        budget, cost_problems = build_budget(
            state, destinations, transport_options, activity_options,
            accommodation_options, selection_problems, whole_trip_budget, fuel,
        )
        selection_problems.extend(cost_problems)
        next_actions = _next_actions(
            state, missing_inputs, selection_problems, transport_options, activity_options,
        )
        if budget.missing_costs:
            next_actions.append(PlanningNextAction(
                code="complete_costs",
                fields=["cost_allowances", "transport_pricing", "accommodation_pricing"],
                label="Review unresolved expenses and add estimates where needed",
            ))
        if budget.fit == "over_budget":
            next_actions.append(PlanningNextAction(code="reduce_costs", label="Adjust the plan to fit your budget"))
        if state.night_count and accommodation_options and not state.selected_accommodation_ids:
            next_actions.append(PlanningNextAction(code="choose_accommodation", label="Choose accommodation"))
        if route.status in {"needs_details", "needs_review"} or route.missing_information:
            next_actions.append(PlanningNextAction(
                code="review_route", fields=route.missing_information,
                label="Review the route and unresolved travel connections",
            ))
        if fuel.status in {"needs_details", "unavailable"}:
            next_actions.append(PlanningNextAction(
                code="complete_fuel_details", fields=fuel.missing_information,
                label="Review fuel assumptions and road-route coverage",
            ))

        return PlanningPreviewResponse(
            input_revision=data.input_revision,
            status=(
                "needs_selection_review" if selection_problems else
                "needs_details" if missing_inputs else "choices_available"
            ),
            state=state,
            whole_trip_budget=whole_trip_budget,
            destinations=[
                PlanningDestination(
                    destination_id=item.destination_id,
                    name=item.name,
                    district=item.district,
                    location=item.location,
                    activities_description=item.activities,
                    catalog_estimated_cost=item.estimated_cost,
                    entrance_fee_description=item.entrance_fee,
                )
                for item in destinations
            ],
            transport_options=transport_options,
            activity_options=activity_options,
            accommodation_options=accommodation_options,
            budget=budget,
            route=route,
            fuel=fuel,
            missing_inputs=missing_inputs,
            selection_problems=selection_problems,
            next_actions=next_actions,
        )


def _transport_options(
    state: PlanningState,
    destinations_by_id: dict[int, Destination],
    transportations: list[Transportation],
) -> list[PlanningTransportOption]:
    if not destinations_by_id:
        return []
    selected = set(state.selected_transport_option_ids)
    options = [
        PlanningTransportOption(
            option_id="mode:personal_vehicle",
            kind="personal_vehicle",
            label="Personal vehicle",
            vehicle_type="Personal vehicle",
            transport_mode="driving",
            missing_information=["route_applicability", "fuel_estimate", "other_vehicle_expenses"],
            selected="mode:personal_vehicle" in selected,
        ),
    ]
    for item in transportations:
        option_id = f"transportation:{item.transportation_id}"
        route_match = _route_match(state, destinations_by_id[item.destination_id], item)
        missing = ["journey_connections"]
        if item.charging_unit is None:
            missing.insert(0, "fare_basis")
        if route_match == "unconfirmed":
            missing.append("route_applicability")
        if state.return_to_origin and route_match != "destination_to_origin":
            missing.append("return_journey")
        options.append(
            PlanningTransportOption(
                option_id=option_id,
                kind="catalog_transport",
                label=f"{item.vehicle_type}: {item.route_from} to {item.route_to}",
                destination_id=item.destination_id,
                transportation_id=item.transportation_id,
                vehicle_type=item.vehicle_type,
                transport_mode=item.transport_mode,
                route_from=item.route_from,
                route_to=item.route_to,
                listed_price=item.price,
                price_basis=item.charging_unit,
                duration_minutes=item.duration_minutes,
                route_match=route_match,
                missing_information=missing,
                selected=option_id in selected,
            ),
        )
    if state.route_preferences is not None:
        options.append(PlanningTransportOption(
            option_id="mode:walking", kind="walking", label="Walking",
            vehicle_type="Walking", transport_mode="walking",
            missing_information=["pedestrian_access", "journey_connections"],
            selected="mode:walking" in selected,
        ))
    return options


def _route_match(state: PlanningState, destination: Destination, item: Transportation) -> str:
    if state.origin is None or not state.origin.label:
        return "unconfirmed"
    origin = _canonical(state.origin.label)
    # These are label matches only; route coverage and feasibility remain unconfirmed.
    target_labels = {_canonical(destination.name)}
    route_from, route_to = _canonical(item.route_from), _canonical(item.route_to)
    if route_from == origin and route_to in target_labels:
        return "origin_to_destination"
    if route_to == origin and route_from in target_labels:
        return "destination_to_origin"
    return "unconfirmed"


def _activity_options(
    state: PlanningState, destinations: list[Destination],
) -> list[PlanningActivityOption]:
    selected = set(state.selected_activity_option_ids)
    result = []
    for destination in destinations:
        seen = set()
        for label in _activity_labels(destination.activities):
            key = _canonical(label)
            if key in seen:
                continue
            seen.add(key)
            digest = hashlib.sha256(key.encode("utf-8")).hexdigest()[:16]
            option_id = f"activity:{destination.destination_id}:{digest}"
            result.append(
                PlanningActivityOption(
                    option_id=option_id,
                    destination_id=destination.destination_id,
                    label=label,
                    selected=option_id in selected,
                ),
            )
    return result


def _activity_labels(description: str | None) -> list[str]:
    if not description:
        return []
    description = re.sub(r"(?m)^\s*(?:[-*•]|\d+[.)])\s+", "", description)
    # Restrictive notes and prose stay intact as a description. Splitting first
    # could turn "No swimming, kayaking" into an advertised activity.
    if re.search(
        r"[.!?:₱$]|\b(?:PHP|pesos?|no|not|prohibited|forbidden|unavailable|closed|"
        r"restricted|visitors?|guests?|can|must|should|may|enjoy|please|when|if|subject)\b",
        description,
        re.IGNORECASE,
    ):
        return []
    parts = []
    current = []
    brackets = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for character in description:
        if character in "([{":
            brackets.append(character)
        elif character in pairs:
            if not brackets or brackets.pop() != pairs[character]:
                return []
        if character in ",;\n\r" and not brackets:
            parts.append("".join(current))
            current = []
        else:
            current.append(character)
    if brackets:
        return []
    parts.append("".join(current))
    result = []
    for part in parts:
        label = part.strip()
        # Long sentences remain a description, not a fabricated selectable product.
        if (
            not label or len(label) > 100 or len(label.split()) > 8
            or re.search(r"[.!?:]|[₱$]|\b(?:PHP|pesos?)\b", label, re.IGNORECASE)
        ):
            continue
        result.append(label)
    return result


def _canonical(value: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def _selection_problems(
    state: PlanningState,
    destinations_by_id: dict[int, Destination],
    transport_options: list[PlanningTransportOption],
    activity_options: list[PlanningActivityOption],
) -> list[PlanningSelectionProblem]:
    problems = []
    for destination_id in state.destination_ids:
        if destination_id not in destinations_by_id:
            problems.append(
                PlanningSelectionProblem(
                    field="destination_ids",
                    option_id=f"destination:{destination_id}",
                    code="destination_unavailable",
                    message="This destination is missing or inactive. Choose an active catalog destination.",
                ),
            )
    for field, available, code in (
        (
            "selected_transport_option_ids",
            {item.option_id for item in transport_options},
            "transport_option_unavailable",
        ),
        (
            "selected_activity_option_ids",
            {item.option_id for item in activity_options},
            "activity_option_unavailable",
        ),
    ):
        for option_id in getattr(state, field):
            if option_id not in available:
                problems.append(
                    PlanningSelectionProblem(
                        field=field,
                        option_id=option_id,
                        code=code,
                        message="This choice is unavailable for the selected destinations. Review your selection.",
                    ),
                )
    return problems


def _missing_inputs(state: PlanningState) -> list[str]:
    missing = []
    if state.origin is None or (state.origin.label is None and state.origin.lat is None):
        missing.append("origin")
    elif state.origin.lat is None:
        missing.append("origin.coordinates")
    if not state.destination_ids:
        missing.append("destination_ids")
    for field in ("total_budget", "traveler_count", "day_count", "night_count", "return_to_origin"):
        if getattr(state, field) is None:
            missing.append(field)
    return missing


def _next_actions(
    state: PlanningState,
    missing_inputs: list[str],
    problems: list[PlanningSelectionProblem],
    transport_options: list[PlanningTransportOption],
    activity_options: list[PlanningActivityOption],
) -> list[PlanningNextAction]:
    actions = []
    if missing_inputs:
        actions.append(PlanningNextAction(
            code="complete_details", fields=missing_inputs, label="Complete the missing trip details",
        ))
    if problems:
        actions.append(PlanningNextAction(
            code="review_selections",
            fields=list(dict.fromkeys(item.field for item in problems)),
            label="Review unavailable selections",
        ))
    if transport_options and not state.selected_transport_option_ids:
        actions.append(PlanningNextAction(code="choose_transport", label="Choose transportation"))
    if activity_options and not state.selected_activity_option_ids:
        actions.append(PlanningNextAction(code="choose_activities", label="Choose activities"))
    return actions
