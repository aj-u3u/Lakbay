"""Advisory pre-trip checks over a single, stateless planning preview."""

from app.features.destinations.models import Destination
from app.features.planning.schemas import (
    PlanningFeedbackFinding,
    PlanningFeedbackResponse,
    PlanningPreviewResponse,
)


def evaluate_preview(
    preview: PlanningPreviewResponse,
    destinations: list[Destination],
    *,
    traveling_with_children: bool | None,
) -> PlanningFeedbackResponse:
    state = preview.state
    findings: list[PlanningFeedbackFinding] = []
    days = state.day_count

    if preview.selection_problems:
        findings.append(PlanningFeedbackFinding(
            code="selection_invalid", category="data", severity="required",
            message="Review unavailable or inconsistent catalog selections before saving.",
            fields=sorted({problem.field for problem in preview.selection_problems}),
        ))
    if preview.missing_inputs:
        findings.append(PlanningFeedbackFinding(
            code="trip_details_missing", category="data", severity="required",
            message="Complete the missing trip details before judging cost or pacing.",
            fields=preview.missing_inputs,
        ))

    unknown_cost_ids = [
        item.destination_id for item in destinations if item.estimated_cost is None
    ]
    if unknown_cost_ids:
        findings.append(PlanningFeedbackFinding(
            code="catalog_cost_unknown", category="budget", severity="review",
            message=(
                "These destinations have no catalog cost estimate. A traveler allowance "
                "can cover planning, but does not verify their actual price."
            ),
            destination_ids=unknown_cost_ids,
        ))
    if preview.budget.completeness == "partial":
        findings.append(PlanningFeedbackFinding(
            code="budget_incomplete", category="budget", severity="review",
            message="The trip estimate is partial; review the unresolved costs before relying on budget fit.",
            fields=sorted({item.reference_id for item in preview.budget.missing_costs}),
        ))
    if preview.budget.fit == "over_budget":
        findings.append(PlanningFeedbackFinding(
            code="over_budget", category="budget", severity="review",
            message="The known minimum trip cost exceeds the stated budget; adjust the plan or budget.",
        ))

    unverified_arrival_ids = [
        item.destination_id for item in destinations if not item.route_ready
    ]
    if unverified_arrival_ids:
        findings.append(PlanningFeedbackFinding(
            code="arrival_unverified", category="route", severity="review",
            message=(
                "Visitor arrival points are unverified for these destinations. "
                "A map route to an attraction pin does not confirm access."
            ),
            destination_ids=unverified_arrival_ids,
        ))

    route = preview.route
    summary = route.summary
    if state.destination_ids and route.status == "not_requested":
        findings.append(PlanningFeedbackFinding(
            code="route_not_requested", category="route", severity="review",
            message="Request a route preview before relying on travel time or stop order.",
            fields=["route_preferences"],
        ))
    elif route.status in {"needs_details", "needs_review"}:
        findings.append(PlanningFeedbackFinding(
            code="route_needs_review", category="route", severity="review",
            message="The selected journey has no complete route estimate yet.",
            fields=route.missing_information,
        ))
    elif summary is not None:
        if summary.is_estimated or not summary.arrival_points_verified:
            findings.append(PlanningFeedbackFinding(
                code="route_estimated", category="route", severity="review",
                message="The route is estimated or uses unverified arrival points; confirm the journey before travel.",
            ))
        if len(state.destination_ids) > 2 and route.order_strategy == "preserve_order":
            findings.append(PlanningFeedbackFinding(
                code="route_order_not_compared", category="route", severity="info",
                message="Stop order was preserved; no alternative order was compared for efficiency.",
            ))
        if days is not None and summary.total_duration_minutes > 240 * days:
            findings.append(PlanningFeedbackFinding(
                code="travel_time_high", category="pacing", severity="review",
                message=(
                    "Total route time averages over four hours per day if spread evenly. "
                    "Review the actual day-by-day schedule."
                ),
                fields=["day_count", "destination_ids"],
            ))
        if (
            days is not None
            and summary.travel_mode == "walking"
            and summary.total_distance_km > 10 * days
        ):
            findings.append(PlanningFeedbackFinding(
                code="walking_distance_high", category="route", severity="review",
                message=(
                    "Walking distance averages over 10 km per day if spread evenly. "
                    "Check terrain, access, and traveler ability."
                ),
                fields=["day_count", "selected_transport_option_ids"],
            ))

    selected_activity_count = sum(item.selected for item in preview.activity_options)
    if days is not None and selected_activity_count > 4 * days:
        findings.append(PlanningFeedbackFinding(
            code="activity_load_high", category="activities", severity="review",
            message=(
                "More than four activities per day are selected. Durations are unknown, "
                "so review the actual schedule."
            ),
            fields=["selected_activity_option_ids", "day_count"],
        ))
    if traveling_with_children:
        unsuitable_ids = [
            item.destination_id for item in destinations if not item.is_kid_friendly
        ]
        if unsuitable_ids:
            findings.append(PlanningFeedbackFinding(
                code="child_suitability_review", category="suitability", severity="review",
                message=(
                    "These destinations are not marked kid friendly. Confirm age, access, "
                    "activity restrictions, and fees with the operator."
                ),
                destination_ids=unsuitable_ids,
            ))

    status = (
        "needs_details" if any(item.severity == "required" for item in findings)
        else "needs_review" if any(item.severity == "review" for item in findings)
        else "no_flagged_issues"
    )
    return PlanningFeedbackResponse(
        input_revision=preview.input_revision,
        traveling_with_children=traveling_with_children,
        status=status,
        findings=findings,
        preview=preview,
    )
